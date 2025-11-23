function! TestRegisteringVimlIndexer()
  " Define a sample indexer
  function! SampleIndexer()
      return {'metadata': [{'title': 'Sample Title', 'author': 'Sample Author'}]}
  endfunction

  " Register the sample indexer
  call struct#metadata#register_viml_indexer('sample', function('SampleIndexer'))

  " Verify that the indexer is registered
  let indexers = struct#metadata#get_viml_indexers()
  call Assert(has_key(indexers, 'sample'), "Indexer 'sample' should be registered")
  call AssertEqual(indexers['sample'], function('SampleIndexer'))
endfunction

function! TestMetadataJobStateInitialization()
  if exists("g:workflow_metadata_jobstate_dir")
    unlet g:workflow_metadata_jobstate_dir
  endif

  " struct initialization should create a jobstate dir
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " Verify that g:workflow_metadata_jobstate_dir exists and is an empty temp directory
  call Assert(exists("g:workflow_metadata_jobstate_dir"), "g:workflow_metadata_jobstate_dir should be defined")
  let dir = g:workflow_metadata_jobstate_dir
  call Assert(isdirectory(dir), "g:workflow_metadata_jobstate_dir should be a directory")
  let files = split(globpath(dir, '*'), "\n")
  call AssertEqual(len(files), 0, "g:workflow_metadata_jobstate_dir should be empty")
endfunction

function! TestCanInitializeJobState()
  " Create a repo to work with (backed by data in tests/data/MetadataTestRepo)
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " initializing job state creates the expected job_dir
  call struct#metadata#initialize_job('test') 
  let expected_job_dir = g:workflow_metadata_jobstate_dir . '/test'
  call AssertDirExists(expected_job_dir, 'Job state directory should be created at expected path')

  " initializing job state using a job id that already exists will throw
  call AssertThrows(function('struct#metadata#initialize_job', ['test']),
        \ 'Duplicate job id: test')

  " clean up
  call delete(expected_job_dir, 'rf')
endfunction

function! TestCanCleanUpJobState()
  " Create a repo to work with (backed by data in tests/data/MetadataTestRepo)
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " initializing job state creates the expected job_dir
  call struct#metadata#initialize_job('test_cleanup') 
  let expected_job_dir = g:workflow_metadata_jobstate_dir . '/test_cleanup'
  call AssertDirExists(expected_job_dir, 'Job state directory should be created at expected path')

  " clean up job state
  call struct#metadata#cleanup_job('test_cleanup')
  call AssertDirNotExists(expected_job_dir, 'Job state directory should be removed after cleanup')
endfunction

function! TestCanLockFilesForJob()
  " Create a repo to work with (backed by data in tests/data/MetadataTestRepo)
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " Initialize job state
  call struct#metadata#initialize_job('test')

  " Locking a path, relative to the repo-root, creates a copy of the file
  " inside g:workflow_metadata_jobstate_dir / job_id
  let locked_files = struct#metadata#lock_files('test', ['notes/Note1.md', 'notes/Note2.md'], v:false)
  let expected_locked_files = [
        \ g:workflow_metadata_jobstate_dir . '/test/notes/Note1.md',
        \ g:workflow_metadata_jobstate_dir . '/test/notes/Note2.md'
        \ ]
  call AssertEqual(expected_locked_files, locked_files, 'Locked files should match expected paths')
  for file in expected_locked_files
    call AssertFileExists(file, 'Locked file should exist: ' . file)
  endfor

  " locking files for a non existent job id will throw
  call AssertThrows(function('struct#metadata#lock_files', ['nonexistent', ['notes/Note1.md'], v:false]),
        \ 'Job does not exist: nonexistent')

  call struct#metadata#cleanup_job('test')
endfunction

" test that locking a non existent file will throw
function! TestLockingNonExistentFileThrows()
  " Locking a non existent file throws
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })
  call struct#metadata#initialize_job('test')

  call AssertThrows(function('struct#metadata#lock_files', ['test', ['notes/NonExistent.md'], v:false]),
        \ 'File `notes/NonExistent.md` does not exist or is not readable.')
  call struct#metadata#cleanup_job('test')
endfunction

function! TestLockCollisionThrowsWithContinueIsFalse()
  " Locking a file with continue set to false throws and deletes the copy if
  " another job already has that file locked
  " Create a repo to work with (backed by data in tests/data/MetadataTestRepo)
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })
  " Initialize job state for two jobs
  call struct#metadata#initialize_job('job1')
  call struct#metadata#initialize_job('job2')

  " Job1 locks Note1.md and Task1.txt
  let locked_files_job1 = struct#metadata#lock_files('job1', ['notes/Note1.md', 'tasks/Task1.txt'], v:false)
  let expected_locked_files_job1 = [
        \ g:workflow_metadata_jobstate_dir . '/job1/notes/Note1.md',
        \ g:workflow_metadata_jobstate_dir . '/job1/tasks/Task1.txt'
        \ ]
  call AssertEqual(expected_locked_files_job1, locked_files_job1, 'Job1 locked files should match expected paths')

  " Job2 attempts to lock Note1.md with continue=false, which should throw
  call AssertThrows(function('struct#metadata#lock_files', ['job2', ['notes/Note1.md', 'notes/Note2.md'], v:false]),
        \ 'Lock conflict for the following files: notes/Note1.md')

  " clean up
  call struct#metadata#cleanup_job('job1')
  call struct#metadata#cleanup_job('job2')
endfunction

function! TestLockCollisionCanContinueWithContinueIsTrue()
  " Locking a file with continue set to true allows locking other files even
  " if some are already locked by another job
  " Create a repo to work with (backed by data in tests/data/MetadataTestRepo)
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " Initialize job state for two jobs
  call struct#metadata#initialize_job('job1')
  call struct#metadata#initialize_job('job2')

  " Job1 locks Note1.md and Task1.txt
  let locked_files_job1 = struct#metadata#lock_files('job1', ['notes/Note1.md', 'tasks/Task1.txt'], v:false)
  let expected_locked_files_job1 = [
        \ g:workflow_metadata_jobstate_dir . '/job1/notes/Note1.md',
        \ g:workflow_metadata_jobstate_dir . '/job1/tasks/Task1.txt'
        \ ]
  call AssertEqual(expected_locked_files_job1, locked_files_job1, 'Job1 locked files should match expected paths')

  " Job2 attempts to lock Note1.md and Note2.md with continue=true
  let locked_files_job2 = struct#metadata#lock_files('job2', ['notes/Note1.md', 'notes/Note2.md'], v:true)
  let expected_locked_files_job2 = [
        \ g:workflow_metadata_jobstate_dir . '/job2/notes/Note2.md'
        \ ]
  call AssertEqual(expected_locked_files_job2, locked_files_job2, 'Job2 should only lock Note2.md successfully')

  " clean up
  call struct#metadata#cleanup_job('job1')
  call struct#metadata#cleanup_job('job2')
endfunction

" TODO
" - executing viml indexers
"   * run a single viml indexer on a specific file and verify output
"   * run all viml indexers on a specific file and verify aggregated output
"   * run viml indexers on multiple files and verify aggregated output
" - registering bash indexers
" - executing bash indexers
" - atomic update tests
"   - needs planning
