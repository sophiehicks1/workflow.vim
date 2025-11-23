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
endfunction

function! struct#metadata#register_viml_indexer(name, indexerFunc) abort
  if !exists('g:workflow_metadata_viml_indexers')
    let g:workflow_metadata_viml_indexers = {}
  endif
  let g:workflow_metadata_viml_indexers[a:name] = a:indexerFunc
endfunction

function! struct#metadata#get_viml_indexers() abort
  if !exists('g:workflow_metadata_viml_indexers')
    return {}
  endif
  return g:workflow_metadata_viml_indexers
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
