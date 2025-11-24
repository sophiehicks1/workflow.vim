" file metadata management system

" Initialize global state for the metadata subsystem
function! struct#metadata#initialize() abort
  if !exists("g:workflow_metadata_jobstate_dir")
    let job_state_dir = struct#utils#from_relative_path('.jobstate')
    if !isdirectory(job_state_dir)
      call mkdir(job_state_dir, 'p')
    endif
    let g:workflow_metadata_jobstate_dir = job_state_dir
  endif
  let g:workflow_metadata_indexers = {}
endfunction

" Locking system
" ===============
" This is a very simple file-based locking system to prevent multiple
" concurrent jobs from modifying the same files at the same time. When a job
" wants to lock a set of files, it copies them into its job directory. If any
" other job has already locked any of those files, the lock attempt fails
" (unless the `continue` flag is set, in which case the conflicting files are
" dropped from the lock attempt).
"
" There are broadly two use cases for this locking system:
"
" - A job will lock repo files before trying to index them, and then perform
"   the indexing work on the locked copies. This prevents the files being
"   modified by other processes while they are being indexed.
"
" - A job will lock metadata index files before trying to update them, perform
"   the update on the locked copies, and then copy the updated files back to
"   the repo. This prevents other jobs from concurrently modifying the same
"   index files.
"
" Usage:
"
"   " Initialize job
"   let job_id = 'my_unique_job_id' " usually this will be the vim job id
"   call struct#metadata#initialize_job(job_id)
"
"   " returns a list of successfully locked file copies
"   let locked_files = struct#metadata#lock_files(job_id, files, continue)
"
"   " ... do work on locked files ...
"
"   " Clean up job
"   call struct#metadata#cleanup_job(job_id)

" job-local state is tracked in a subdirectory of
" g:workflow_metadata_jobstate_dir
function! s:job_state_dir(job_id)
  return g:workflow_metadata_jobstate_dir . '/' . a:job_id
endfunction

function! struct#metadata#initialize_job(job_id)
  let job_dir = s:job_state_dir(a:job_id)
  if isdirectory(job_dir)
    throw 'Duplicate job id: ' . a:job_id
  else
    call mkdir(job_dir, 'p')
  endif
  return job_dir
endfunction

function! struct#metadata#cleanup_job(job_id)
  let job_dir = s:job_state_dir(a:job_id)
  if isdirectory(job_dir)
    call delete(job_dir, 'rf')
  endif
endfunction

" Copies the given files into the given job directory.
function! s:try_getting_locks(job_dir, files) abort
  " Copy all files first...
  let locked_files = []
  for relative_path in a:files
    let absolute_path = struct#utils#from_relative_path(relative_path)
    if !filereadable(absolute_path)
      throw 'File `' . relative_path . '` does not exist or is not readable.'
    endif
    let dest_file = a:job_dir . '/' . relative_path
    call mkdir(fnamemodify(dest_file, ':h'), 'p')
    call filecopy(absolute_path, dest_file)
    call add(locked_files, dest_file)
  endfor
  return locked_files
endfunction

" Returns a list of all files locked by other jobs (i.e. excluding the given job
" id, which is the current job trying to acquire new locks)
function! s:get_locked_files(exclude_job_id) abort
  let locked_files = []
  if !isdirectory(g:workflow_metadata_jobstate_dir)
    throw 'Job state directory does not exist: ' . g:workflow_metadata_jobstate_dir
  endif

  let job_dirs = split(globpath(g:workflow_metadata_jobstate_dir, '*'), "\n")
  for job_dir in job_dirs
    let job_id = fnamemodify(job_dir, ':t')
    if job_id ==# a:exclude_job_id
      continue
    endif
    let files = split(globpath(job_dir, '**/*'), "\n")
    for file in files
      if glob(file) !=# ''
        let relative_path = substitute(file, '^' . escape(job_dir . '/', '\'), '', '')
        call add(locked_files, relative_path)
      endif
    endfor
  endfor

  return locked_files
endfunction

function! struct#metadata#lock_files(job_id, files, continue) abort
  " Validate job exists
  let job_dir = s:job_state_dir(a:job_id)
  if !isdirectory(job_dir)
    throw 'Job does not exist: ' . a:job_id
  endif

  " Copy files into job dir
  let locked_files = s:try_getting_locks(job_dir, a:files)

  " Then check for other jobs locking the same files
  let existing_locks = s:get_locked_files(a:job_id)
  let lock_conflicts = []
  for file in a:files
    if index(existing_locks, file) != -1
      call add(lock_conflicts, file)
    endif
  endfor
  if !empty(lock_conflicts) && !a:continue
    " Remove copied files
    for file in locked_files
      call delete(file)
    endfor
    throw 'Lock conflict for the following files: ' . join(lock_conflicts, ', ')
  elseif !empty(lock_conflicts) && a:continue
    " Remove conflicting files from locked_files
    let locked_files = filter(locked_files,
          \ 'index(lock_conflicts, substitute(v:val, "^' . escape(job_dir . '/', '\') . '", "", "")) == -1')
  endif

  return locked_files
endfunction

" Indexer system
" ==============
"
" The metadata indexing system is a modular system for extracting structured
" data such as tags, links, and other metadata from files in the repository.
" Users can register custom metadata indexers to extend the kinds of metadata
" supported by the system. The system will automatically maintain a metadata
" store containing the indexed metadata for all files in the repository,
" updating it as files are added, modified, or deleted.
"
" Indexers can currently only be added as vimscript functions, but support for
" bash indexers may be added in the future.
"
" - vimscript indexers should operate on the current buffer, and return a
"   dictionary mapping table-name to rows. Each row is itself a dictionary
"   mapping column-names to values.
"
" - bash indexers have not been implemented yet. API will probably be as
"   follows (TBC):
"    * The indexer is a bash script that takes a file path as its first
"      argument.
"    * The script outputs csv data to stdout, with the first column being
"      the table name, and subsequent columns being the column values. The first
"      row should be a header row with column names.

function! struct#metadata#register_viml_indexer(name, indexerFunc) abort
  if !exists('g:workflow_metadata_indexers')
    throw "Can't register indexer before Workflow.vim has finished initialization"
  endif
  if has_key(g:workflow_metadata_indexers, a:name)
    echohl WarningMsg
    echom 'Indexer ' . a:name . ' is already registered. Overwriting.'
    echohl None
  endif
  let g:workflow_metadata_indexers[a:name] = a:indexerFunc
endfunction

" Enrich indexed rows with metadata about source file, indexer, and timestamp
" The timestamp is the last modified time of the indexed file, since in
" production, indexers will be run on locked copies of files, so the results
" returned by the indexer will represent the state of the file at the time it
" was locked.
function! s:enrich_indexed_rows(indexer_name, indexed_file, rows) abort
  let enriched_rows = []
  let timestamp = systemlist('stat -c %Y ' . shellescape(a:indexed_file))[0]
  let filepath = struct#utils#to_relative_path(a:indexed_file)
  for row in a:rows
    let enriched_row = copy(row)
    let enriched_row['__source_file'] = filepath
    let enriched_row['__indexer'] = a:indexer_name
    let enriched_row['__timestamp'] = timestamp
    call add(enriched_rows, enriched_row)
  endfor
  return enriched_rows
endfunction

function! struct#metadata#run_indexer(indexer_name) abort
  if !exists('g:workflow_metadata_indexers')
    throw "Can't run indexer before Workflow.vim has finished initialization"
  endif
  if !has_key(g:workflow_metadata_indexers, a:indexer_name)
    throw 'No such viml indexer: ' . a:indexer_name
  endif
  let IndexerFunc = g:workflow_metadata_indexers[a:indexer_name]
  let results = call(IndexerFunc, [])
  let indexed_file = expand('%:p')
  for [table_name, rows] in items(results)
    let enriched_rows = s:enrich_indexed_rows(a:indexer_name, indexed_file, rows)
    let results[table_name] = enriched_rows
  endfor
  return results
endfunction

function! struct#metadata#run_all_indexers() abort
  if !exists('g:workflow_metadata_indexers')
    throw "Can't run indexers before Workflow.vim has finished initialization"
  endif
  let all_results = {}
  for indexer_name in keys(g:workflow_metadata_indexers)
    let indexer_results = struct#metadata#run_indexer(indexer_name)
    for [table_name, rows] in items(indexer_results)
      if !has_key(all_results, table_name)
        let all_results[table_name] = []
      endif
      let all_results[table_name] += rows
    endfor
  endfor
  return all_results
endfunction

" TODO refactor to remove duplicated result merging logic
function! struct#metadata#index_all_loaded_buffers() abort
  let all_results = {}
  for bufnum in range(1, bufnr('$'))
    if bufloaded(bufnum)
      execute 'buffer' bufnum
      let indexer_results = struct#metadata#run_all_indexers()
      for [table_name, rows] in items(indexer_results)
        if !has_key(all_results, table_name)
          let all_results[table_name] = []
        endif
        let all_results[table_name] += rows
      endfor
    endif
  endfor
  return all_results
endfunction
