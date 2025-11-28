" file metadata management system

" Initialize global state for the metadata subsystem
function! struct#metadata#initialize() abort
  let job_state_dir = struct#utils#from_relative_path('.jobstate')
  if !isdirectory(job_state_dir)
    call mkdir(job_state_dir, 'p')
  endif
  let g:workflow_metadata_jobstate_dir = job_state_dir
  let g:workflow_metadata_indexers = {}
endfunction

function! s:log(message) abort
  let log_file = struct#utils#from_relative_path('.log')
  let timestamp = strftime('%Y-%m-%d %H:%M:%S')
  let log_message = '[' . timestamp . '][' . s:get_job_id() . '] '. a:message
  call writefile([log_message], log_file, 'a')
endfunction

function! s:get_log_level() abort
  let log_level = 'warn'
  if exists('g:workflow_metadata_log_level')
    let log_level = g:workflow_metadata_log_level
  endif
  return {'error': 0, 'warn': 1, 'info': 2, 'debug': 3}[log_level]
endfunction

function! struct#metadata#log_debug(message) abort
  if s:get_log_level() >= 3
    call s:log('DEBUG: ' . a:message)
  endif
endfunction

function! struct#metadata#log_info(message) abort
  if s:get_log_level() >= 2
    call s:log('INFO: ' . a:message)
  endif
endfunction

function! struct#metadata#log_warn(message) abort
  if s:get_log_level() >= 1
    call s:log('WARN: ' . a:message)
  endif
endfunction

function! struct#metadata#log_error(message) abort
  if s:get_log_level() >= 0
    call s:log('ERROR: ' . a:message)
  endif
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
" Important: This locking system assumes that each job is in its own instance of
" vim, and that the job id is unique across all running instances. IF YOU HAVE
" TWO JOBS RUNNING IN THE SAME VIM INSTANCE BAD, THINGS WILL DEFINITELY HAPPEN.
"
" Usage:
"
"   " Initialize job
"   let job_id = 'my_unique_job_id' " usually this will be the vim job id
"   call struct#metadata#initialize_job(job_id)
"
"   " returns a list of successfully locked file copies
"   let locked_files = struct#metadata#lock_files(files, continue)
"
"   " ... do work on locked files ...
"
"   " Clean up job
"   call struct#metadata#cleanup_job()

" job-local state is tracked in a subdirectory of
" g:workflow_metadata_jobstate_dir
"
" Notes:
" - job ids must be unique. Attempting to initialize a job with an existing
"   id will throw an error. It is recommended to use the vim job id as the job
"   id to ensure uniqueness.
" - This is for locking files that are managed by workflow.vim only. It does not
"   provide any general-purpose file locking functionality, and assumes
"   everything is relative to the repo root.
" - Use continue = true when a job makes sense with partial locks (e.g. indexing
"   files, where it can still index files that aren't locked by other jobs))
" - Use continue = false when a job requires all files to be locked (e.g.
"   updating index files, where partial updates would corrupt the index)
function! s:job_state_dir(fail_if_no_job_id=v:true) abort
  let job_id = ''
  if a:fail_if_no_job_id
    let job_id = s:ensure_job_id()
  else
    let job_id = s:get_job_id()
  endif
  return g:workflow_metadata_jobstate_dir . '/' . job_id
endfunction

" Get the current job id, or 'local' if not set
function! s:get_job_id() abort
  return get(g:, 'workflow_current_job_id', 'local')
endfunction

" Get the current job id, throwing an error if not set
function! s:ensure_job_id() abort
  let job_id = s:get_job_id()
  if job_id ==# 'local'
    throw 'No job initialized.'
  endif
  return job_id
endfunction

function! struct#metadata#initialize_job(job_id)
  call struct#metadata#log_info('Initializing job' . a:job_id)
  let g:workflow_current_job_id = a:job_id
  let job_dir = s:job_state_dir()
  if isdirectory(job_dir)
    call struct#metadata#log_error('Duplicate job id detected: ' . a:job_id)
    throw 'Duplicate job id: ' . a:job_id
  else
    call mkdir(job_dir, 'p')
  endif
  return job_dir
endfunction

function! struct#metadata#cleanup_job()
  let job_id = s:ensure_job_id()
  let job_dir = s:job_state_dir()
  if isdirectory(job_dir)
    call delete(job_dir, 'rf')
  endif
  unlet g:workflow_current_job_id
endfunction

" Copies the given files into the given job directory.
function! s:try_getting_locks(job_dir, files, skip_non_existent) abort
  " Copy all files first...
  let locked_files = []
  for relative_path in a:files
    let absolute_path = struct#utils#from_relative_path(relative_path)
    if !filereadable(absolute_path)
      if a:skip_non_existent
        continue
      else
        " if the file doesn't exist, create an empty file in the job dir to
        " represent the lock. This is needed so that we can lock files that
        " we're about to create in the repo.
        let dest_file = s:absolute_path_in_job_dir(relative_path)
        call mkdir(fnamemodify(dest_file, ':h'), 'p')
        call writefile([], dest_file)
        call add(locked_files, dest_file)
      endif
    else
      let dest_file = s:absolute_path_in_job_dir(relative_path)
      call mkdir(fnamemodify(dest_file, ':h'), 'p')
      call filecopy(absolute_path, dest_file)
      call add(locked_files, dest_file)
    endif
  endfor
  return locked_files
endfunction

" Returns a list of all files locked by other jobs (i.e. excluding the current job
" id, which is trying to acquire new locks)
function! s:get_locked_files() abort
  let exclude_job_id = s:ensure_job_id()
  let locked_files = []
  if !isdirectory(g:workflow_metadata_jobstate_dir)
    throw 'Job state directory does not exist: ' . g:workflow_metadata_jobstate_dir
  endif

  let job_dirs = split(globpath(g:workflow_metadata_jobstate_dir, '*'), "\n")
  for job_dir in job_dirs
    let job_id = fnamemodify(job_dir, ':t')
    if job_id ==# exclude_job_id
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

" Try to acquire locks for the requested files, and return absolute paths for
" locked copies of the successfully locked files. If continue is false,
" non-existent files will locked as if they were empty files, and lock
" conflicts will cause an error; if true, conflicting files and non-existent
" files will be skipped.
function! struct#metadata#lock_files(files, continue) abort
  let job_id = s:ensure_job_id()
  " Validate job exists
  let job_dir = s:job_state_dir()
  if !isdirectory(job_dir)
    throw 'Job does not exist: ' . job_id
  endif

  " Copy files into job dir
  let locked_files = s:try_getting_locks(job_dir, a:files, a:continue)

  " Then check for other jobs locking the same files
  let existing_locks = s:get_locked_files()
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

" acquire locks for as many of a:files as possible, and then call a:func on
" locked copies (in the job dir) for the successfully locked files. Returns a
" map from file path to the result of a:func for that file.
"
" Note: files will be passed as absolute paths to the locked copies in the job
" dir, so struct#utils#to_relative_path will not work as expected inside a:func.
function! s:with_available_file_locks(files, func) abort
  call struct#metadata#log_info('Attempting to lock ' . len(a:files) . ' files, with continue=true.')
  let locked_files = struct#metadata#lock_files(a:files, v:true)
  call struct#metadata#log_info('Successfully locked ' . len(locked_files) . ' files.')
  let results = {}
  try
    for file in locked_files
      call struct#metadata#log_debug('Processing locked file: ' . file)
      let results[file] = call(a:func, [file])
    endfor
  endtry
  return results
endfunction

" acquire locks for all of a:files, and then call a:func on locked copies (in
" the job dir) for each file. Returns a map of locked file paths to the result
" of a:func for that file. Throws an error if any file cannot be locked.
"
" Note: files will be passed as absolute paths to the locked copies in the job
" dir, so struct#utils#to_relative_path will not work as expected inside
" a:func.
function! s:with_all_file_locks(files, func) abort
  call struct#metadata#log_info('Attempting to lock ' . len(a:files) . ' files, with continue=false.')
  let locked_files = struct#metadata#lock_files(a:files, v:false)
  call struct#metadata#log_info('Successfully locked all ' . len(locked_files) . ' files.')
  let results = {}
  try
    for file in locked_files
      call struct#metadata#log_debug('Processing locked file: ' . file)
      let results[file] = call(a:func, [file])
    endfor
  endtry
  return results
endfunction

function! s:with_exponential_backoff(max_attempts, func) abort
  let attempts = 0
  let done = 0
  while !done && attempts < a:max_attempts
    try
      call call(a:func, [])
      let done = 1
    catch /Lock conflict/
      let attempts += 1
      let wait_time = attempts * attempts * attempts * 100
      call struct#metadata#log_warn('Operation failed due to lock conflict (attempt ' . (attempts + 1) . '). Waiting ' . wait_time . 'ms before retrying.')
      " exponential backoff
      execute "sleep " . wait_time . "m"
      call struct#metadata#log_info('Retrying...')
    endtry
  endwhile
  if !done
    throw 'Operation failed due to lock conflicts after multiple attempts.'
  endif
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

function! s:path_relative_to_job_dir(absolute_path) abort
  let job_dir = s:job_state_dir(v:false)
  return substitute(a:absolute_path, '^' . escape(job_dir . '/', '\'), '', '')
endfunction

function! s:absolute_path_in_job_dir(relative_path) abort
  let job_dir = s:job_state_dir(v:false)
  return job_dir . '/' . a:relative_path
endfunction

function! s:get_file_timestamp(file) abort
  return systemlist('stat -c %Y ' . shellescape(a:file))[0]
endfunction

" Enrich indexed rows with metadata about source file, indexer, and timestamp
" The timestamp is the last modified time of the indexed file, since in
" production, indexers will be run on locked copies of files, so the results
" returned by the indexer will represent the state of the file at the time it
" was locked.
function! s:enrich_indexed_rows(indexer_name, indexed_file, rows) abort
  let enriched_rows = []
  let timestamp = s:get_file_timestamp(a:indexed_file)
  let filepath = s:path_relative_to_job_dir(a:indexed_file)
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
    call struct#metadata#log_debug('Indexer ' . a:indexer_name .
          \ ' produced ' . len(enriched_rows) . ' rows for table ' . table_name .
          \ ' from file ' . s:path_relative_to_job_dir(indexed_file))
  endfor
  return results
endfunction

function! s:merge_indexer_results(existing_results, indexer_results) abort
  let all_results = copy(a:existing_results)
  for [table_name, rows] in items(a:indexer_results)
    if !has_key(all_results, table_name)
      let all_results[table_name] = []
    endif
    let all_results[table_name] += rows
  endfor
  return all_results
endfunction

function! struct#metadata#run_all_indexers() abort
  if !exists('g:workflow_metadata_indexers')
    throw "Can't run indexers before Workflow.vim has finished initialization"
  endif
  let all_results = {}
  for indexer_name in keys(g:workflow_metadata_indexers)
    call struct#metadata#log_debug('Running indexer: ' . indexer_name)
    let indexer_results = struct#metadata#run_indexer(indexer_name)
    let all_results = s:merge_indexer_results(all_results, indexer_results)
  endfor
  return all_results
endfunction

" Indexing job
function! s:index_file(file) abort
  call struct#metadata#log_info('Indexing file: ' . a:file)
  execute 'e ' . a:file
  let results = struct#metadata#run_all_indexers()
  execute 'bw!'
  return results
endfunction

function! s:write_indexing_results_to_store(results) abort
  let table_names = keys(a:results)
  let output_files = {}
  for table_name in table_names
    let output_files[table_name] = '.metadata/' . table_name . '.csv'
  endfor
  call struct#metadata#log_info('Attempting to acquire locks for writing metadata to ' . len(table_names) . ' files.')
  let locked_output_files = struct#metadata#lock_files(values(output_files), v:false)
  call struct#metadata#log_info('Acquired locks for ' . len(locked_output_files) . ' metadata files. Writing data.')
  " Write data to locked files
  for table_name in table_names
    call struct#metadata#log_debug('Writing ' . len(a:results[table_name]) . ' rows to table ' . table_name . '.')
    let output_file = output_files[table_name]
    let rows = a:results[table_name]
    call struct#csv#append_to_file(s:absolute_path_in_job_dir(output_file), rows)
  endfor
  " copy locked files back to repo
  call s:persist_updated_files(locked_output_files)
endfunction

" This garbage is needed because filecopy() in vim fails silently and
" counterintuitively in a bunch of different ways.
function! s:safe_filecopy(locked_file, dest_file) abort
  if filereadable(a:dest_file)
    call struct#metadata#log_debug('Deleting existing metadata file in repo: ' . a:dest_file)
    let delete_result = ! delete(a:dest_file)
    if delete_result
      call struct#metadata#log_debug('Deleted existing metadata file: ' . a:dest_file)
    else
      throw 'Failed to delete existing metadata file: ' . a:dest_file
    endif
  endif
  if !isdirectory(fnamemodify(a:dest_file, ':h'))
    call struct#metadata#log_debug('Creating directory for metadata file: ' . fnamemodify(a:dest_file, ':h'))
    call mkdir(fnamemodify(a:dest_file, ':h'), 'p')
    if isdirectory(fnamemodify(a:dest_file, ':h'))
      call struct#metadata#log_debug('Created directory ' . fnamemodify(a:dest_file, ':h'))
    else
      throw 'Failed to create directory for metadata file: ' . fnamemodify(a:dest_file, ':h')
    endif
  endif
  let copy_result = filecopy(a:locked_file, a:dest_file)
  if copy_result
    call struct#metadata#log_debug('Persisted updated metadata file to repo: ' . a:dest_file)
  else
    throw 'Failed to persist updated metadata file to repo: ' . a:dest_file
  endif
endfunction

function! s:persist_updated_files(locked_output_files) abort
  for locked_file in a:locked_output_files
    let relative_path = s:path_relative_to_job_dir(locked_file)
    let dest_file = struct#utils#from_relative_path(relative_path)
    call struct#metadata#log_debug('Copying locked metadata file back to repo: ' . locked_file . ' -> ' . dest_file)
    call s:safe_filecopy(locked_file, dest_file)
  endfor
endfunction

function! struct#metadata#index_files(job_id, files) abort
  try
    call struct#metadata#initialize_job(a:job_id)
    call struct#metadata#log_info('Starting indexing job for ' . len(a:files) . ' files.')
    call struct#metadata#log_debug('Files to index: ' . join(a:files, ', '))
    let separate_results = s:with_available_file_locks(a:files, {f -> s:index_file(f)})
    let merged_results = {}
    for file_results in values(separate_results)
      let merged_results = s:merge_indexer_results(merged_results, file_results)
    endfor
    let results = merged_results
    call struct#metadata#log_info('Indexing complete. Indexed ' . len(a:files) . ' files, and found'.
          \ ' data for ' . len(keys(merged_results)) . ' tables.')

    call s:with_exponential_backoff(10, { -> s:write_indexing_results_to_store(merged_results) })
  catch
    call struct#metadata#log_error('Indexing job failed: ' . v:exception)
    throw 'Indexing job failed: ' . v:exception
  finally
    call struct#metadata#cleanup_job()
  endtry
endfunction

function! s:delete_files_from_index(files)
  let all_index_files = globpath(struct#utils#from_relative_path('.metadata'), '*.csv', 0, 1)
  let updated_index_files = []
  for index_file in all_index_files
    call struct#metadata#log_debug('Processing index file for deletions: ' . index_file)
    let rows = struct#csv#read_file(index_file)
    let filtered_rows = []
    for row in rows
      let source_file = row['__source_file']
      if index(a:files, source_file) == -1
        call add(filtered_rows, row)
      else
        call struct#metadata#log_debug('Deleting row for file ' . source_file . ' from index file ' . index_file)
      endif
    endfor
    let num_deleted = len(rows) - len(filtered_rows)
    if num_deleted > 0
      call struct#metadata#log_info('Deleting ' . num_deleted . ' rows from index file ' . index_file)
      call struct#csv#overwrite_file(index_file, filtered_rows)
      call add(updated_index_files, index_file)
    else
      call struct#metadata#log_debug('No rows to delete from index file ' . index_file)
    endif
  endfor
  call s:persist_updated_files(updated_index_files)
endfunction

function! struct#metadata#delete_from_index(job_id, files) abort
  try
    call struct#metadata#initialize_job(a:job_id)
    call struct#metadata#log_info('Starting deletion job for ' . len(a:files) . ' files.')
    call s:with_exponential_backoff(10, { -> s:delete_files_from_index(a:files) })
  catch
    call struct#metadata#log_error('Index delete job failed: ' . v:exception)
    throw 'Index delete job failed: ' . v:exception
  finally
    call struct#metadata#cleanup_job()
  endtry
endfunction

" for a given (__source_file, __indexer) pair, keep only the rows from the
" most recent __timestamp
function! s:compress_index_file(index_file) abort
  call struct#metadata#log_info('Compressing index file: ' . a:index_file)
  let rows = struct#csv#read_file(a:index_file)
  let update_times = s:file_and_indexer_update_times()
  let compressed_rows = []
  for row in rows
    let source_file = row['__source_file']
    let indexer = row['__indexer']
    let timestamp = str2nr(row['__timestamp'])
    if has_key(update_times, source_file) && has_key(update_times[source_file], indexer)
      let latest_timestamp = update_times[source_file][indexer]
      if timestamp == latest_timestamp
        call add(compressed_rows, row)
      endif
    else
      throw 'Inconsistent state: no update time found for file ' . source_file .
            \ ' and indexer ' . indexer
    endif
  endfor
  let num_removed = len(rows) - len(compressed_rows)
  call struct#metadata#log_debug('Compressed rows: ' . len(compressed_rows))
  call struct#metadata#log_debug('Rows removed: ' . num_removed)
  if num_removed > 0
    call struct#metadata#log_info('Removed ' . num_removed . ' duplicate rows from index file ' . a:index_file)
    call struct#csv#overwrite_file(a:index_file, compressed_rows)
  else
    call struct#metadata#log_debug('No duplicate rows found in index file ' . a:index_file)
  endif
endfunction

" Remove duplicate entries from the index files to reduce size
function! struct#metadata#compress_index(job_id) abort
  call struct#metadata#initialize_job(a:job_id)
  call struct#metadata#log_info('Starting index compression job.')

  try
    let index_files = map(globpath(struct#utils#from_relative_path('.metadata'), '*.csv', 0, 1), 'struct#utils#to_relative_path(v:val)')
    call struct#metadata#log_info('Found ' . len(index_files) . ' index files to compress.')
    let results = s:with_all_file_locks(index_files, {file -> s:compress_index_file(file)})
    call s:persist_updated_files(keys(results))
    call struct#metadata#log_info('Index compression job complete.')
  catch
    call struct#metadata#log_error('Index compression job failed: ' . v:exception)
    throw 'Index compression job failed: ' . v:exception
  finally
    call struct#metadata#cleanup_job()
  endtry
endfunction

" Get the last indexed timestamp for all file/indexer combinations
function! s:file_and_indexer_update_times() abort
  let last_updates = {}
  let metadata_files = globpath(struct#utils#from_relative_path('.metadata'), '*.csv', 0, 1)
  for metadata_file in metadata_files
    let rows = struct#csv#read_file(metadata_file)
    for row in rows
      let file = row['__source_file']
      let indexer = row['__indexer']
      let timestamp = str2nr(row['__timestamp'])
      if !has_key(last_updates, file)
        let last_updates[file] = {}
      endif
      if !has_key(last_updates[file], indexer) || timestamp > last_updates[file][indexer]
        let last_updates[file][indexer] = timestamp
      endif
    endfor
  endfor
  return last_updates
endfunction

function! s:get_files_to_index(all_files, last_updates) abort
  let files_to_index = []
  for file in a:all_files
    let absolute_path = struct#utils#from_relative_path(file)
    let file_update_timestamp = s:get_file_timestamp(absolute_path)
    let needs_indexing = 0
    if !has_key(a:last_updates, file)
      let needs_indexing = 1
    else
      " Check if any indexer is out of date
      let earliest_timestamp = min(values(a:last_updates[file]))
      if file_update_timestamp > earliest_timestamp
        let needs_indexing = 1
      else
        " Check if any indexer is missing
        let indexer_names = keys(g:workflow_metadata_indexers)
        for indexer_name in indexer_names
          if !has_key(a:last_updates[file], indexer_name)
            let needs_indexing = 1
          endif
        endfor
      endif
    endif
    if needs_indexing
      call add(files_to_index, file)
    endif
  endfor
  return files_to_index
endfunction

function! s:get_files_to_delete(all_files, last_updates) abort
  let files_to_delete = []
  for file in keys(a:last_updates)
    if index(a:all_files, file) == -1
      call add(files_to_delete, file)
    endif
  endfor
  return files_to_delete
endfunction

function! struct#metadata#indexing_backlog() abort
  let all_files = struct#utils#all_repo_files()
  let last_updates = s:file_and_indexer_update_times()
  let files_to_index = s:get_files_to_index(all_files, last_updates)
  let files_to_delete = s:get_files_to_delete(all_files, last_updates)
  return {'to_index': files_to_index, 'to_delete': files_to_delete}
endfunction
