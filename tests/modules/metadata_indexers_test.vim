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

function! TestRegisteringVimlIndexer()
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " Define a sample indexer
  function! SampleIndexer()
    return {'metadata': [{'title': 'Sample Title', 'author': 'Sample Author'}]}
  endfunction

  " Use a different name each time, so that the test won't pass because of
  " leftover state from a previous run
  let indexer_name = 'sample_' . string(localtime())

  " Register the sample indexer and verify
  call struct#metadata#register_viml_indexer(indexer_name, function('SampleIndexer'))
  call Assert(has_key(g:workflow_metadata_indexers, indexer_name), 
        \ 'Indexer "' . indexer_name . '" should be registered')

  " Registering duplicate indexer name should warn and overwrite
  function! AnotherSampleIndexer()
    return {'metadata': [{'title': 'Another Title'}]}
  endfunction

  call struct#metadata#register_viml_indexer(indexer_name, function('AnotherSampleIndexer'))
  let expected_warning = 'Indexer with name "' . indexer_name . '" is already registered. Overwriting.'
  call AssertEqual(g:workflow_metadata_indexers[indexer_name], function('AnotherSampleIndexer'),
        \ 'Indexer "' . indexer_name . '" should be overwritten with the new function')
endfunction

" Define an indexer that extracts all the words from a buffer
function! s:WordIndexer()
  let l:words = []

  for lnum in range(1, line('$'))
    let line = getline(lnum)
    let l:line_words = split(line, '\W\+')
    for word in l:line_words
      call extend(l:words, [{'word':word, 'line':lnum}])
    endfor
  endfor
  return {'words': l:words}
endfunction

function! TestRunningASingleVimlIndexer()
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " Register the WordIndexer
  call struct#metadata#register_viml_indexer('word_indexer', function('s:WordIndexer'))

  " Open a test buffer
  Page NoteWithWords
  call append(0, 'foo bar')
  call append(1, 'baz')
  3d
  write

  let expected_timestamp = systemlist('stat -c %Y ' . shellescape(expand('%:p')))[0]

  " Run the indexer on the current buffer
  let results = struct#metadata#run_indexer('word_indexer')
  let expected_results = {'words': [
        \ {'word': 'foo', 'line': 1,
        \  '__source_file': 'notes/NoteWithWords.md', '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \ {'word': 'bar', 'line': 1,
        \  '__source_file': 'notes/NoteWithWords.md', '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \ {'word': 'baz', 'line': 2,
        \  '__source_file': 'notes/NoteWithWords.md', '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \ ]}
  call AssertDeepEqual(expected_results, results, 'Indexer should extract words from the buffer correctly')

  " Clean up
  bd!
  call delete(g:test_workspace . '/MetadataTestRepo/notes/NoteWithWords.md')
endfunction

" a dummy indexer that assumes the first line is the title and also adds an
" index for reverse words, because I need something that will write to the
" same table from a second indexer
function! s:TitleIndexer()
  let title = getline(1)
  let l:words = []

  for lnum in range(1, line('$'))
    let line = getline(lnum)
    let l:line_words = split(line, '\W\+')
    for word in l:line_words
      call extend(l:words, [{'word':reverse(word), 'line':lnum}])
    endfor
  endfor
  return {'words': l:words, 'titles': [{'title': title}]}
endfunction

function! TestRunSeveralVimlIndexersOnASingleFile()
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " Register the WordIndexer and TitleIndexer
  call struct#metadata#register_viml_indexer('word_indexer', function('s:WordIndexer'))
  call struct#metadata#register_viml_indexer('title_indexer', function('s:TitleIndexer'))

  " Open a test buffer
  Page NoteWithWords
  call append(0, 'foo bar')
  call append(1, 'baz')
  3d
  write

  let expected_timestamp = systemlist('stat -c %Y ' . shellescape(expand('%:p')))[0]

  " Run the indexers on the current buffer
  let results = struct#metadata#run_all_indexers()
  let expected_results = {
        \ 'words': [
        \   {'word': 'oof', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords.md', '__indexer': 'title_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'rab', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords.md', '__indexer': 'title_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'zab', 'line': 2,
        \    '__source_file': 'notes/NoteWithWords.md', '__indexer': 'title_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'foo', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords.md', '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'bar', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords.md', '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'baz', 'line': 2,
        \    '__source_file': 'notes/NoteWithWords.md', '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \ ],
        \ 'titles': [
        \   {'title': 'foo bar',
        \    '__source_file': 'notes/NoteWithWords.md', '__indexer': 'title_indexer', '__timestamp': expected_timestamp},
        \ ]
        \ }
  call AssertDeepEqual(expected_results, results, 'Indexers should aggregate results from multiple indexers correctly')
endfunction

function! TestRunSeveralVimlIndexersOnMutipleBuffers()
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })
  
  " Register the WordIndexer and TitleIndexer
  call struct#metadata#register_viml_indexer('word_indexer', function('s:WordIndexer'))
  call struct#metadata#register_viml_indexer('title_indexer', function('s:TitleIndexer'))

  " clear any loaded buffers
  bufdo bwipeout!

  " Open first test buffer
  Page NoteWithWords1
  call append(0, 'foo bar')
  call append(1, 'baz')
  3d
  write

  let expected_timestamp1 = systemlist('stat -c %Y ' . shellescape(expand('%:p')))[0]

  " Open second test buffer
  Page NoteWithWords2
  call append(0, 'hello world')
  call append(1, 'foo baz')
  3d
  write

  let expected_timestamp2 = systemlist('stat -c %Y ' . shellescape(expand('%:p')))[0]

  let actual_results = struct#metadata#index_all_loaded_buffers()

  " Verify aggregated results
  let expected_results = {
        \ 'words': [
        \   {'word': 'oof', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords1.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp1},
        \   {'word': 'rab', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords1.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp1},
        \   {'word': 'zab', 'line': 2,
        \    '__source_file': 'notes/NoteWithWords1.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp1},
        \   {'word': 'foo', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords1.md', '__indexer': 'word_indexer',
        \    '__timestamp': expected_timestamp1},
        \   {'word': 'bar', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords1.md', '__indexer': 'word_indexer',
        \    '__timestamp': expected_timestamp1},
        \   {'word': 'baz', 'line': 2,
        \    '__source_file': 'notes/NoteWithWords1.md', '__indexer': 'word_indexer',
        \    '__timestamp': expected_timestamp1},
        \   {'word': 'olleh', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp2},
        \   {'word': 'dlrow', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp2},
        \   {'word': 'oof', 'line': 2,
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp2},
        \   {'word': 'zab', 'line': 2,
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp2},
        \   {'word': 'hello', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'word_indexer',
        \    '__timestamp': expected_timestamp2},
        \   {'word': 'world', 'line': 1,
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'word_indexer',
        \    '__timestamp': expected_timestamp2},
        \   {'word': 'foo', 'line': 2,
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'word_indexer',
        \    '__timestamp': expected_timestamp2},
        \   {'word': 'baz', 'line': 2,
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'word_indexer',
        \    '__timestamp': expected_timestamp2},
        \ ],
        \ 'titles': [
        \   {'title': 'foo bar',
        \    '__source_file': 'notes/NoteWithWords1.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp1},
        \   {'title': 'hello world',
        \    '__source_file': 'notes/NoteWithWords2.md', '__indexer': 'title_indexer',
        \    '__timestamp': expected_timestamp2},
        \ ]
        \ }
  call AssertDeepEqual(expected_results, actual_results,
        \ 'Indexers should aggregate results from multiple buffers correctly')

  " Clean up
  bd!
  bd!
  call delete(g:test_workspace . '/MetadataTestRepo/notes/NoteWithWords1.md')
  call delete(g:test_workspace . '/MetadataTestRepo/notes/NoteWithWords2.md')
endfunction

function! TestRegisteringIndexerBeforeInitializationThrows()
  " Ensure that registering an indexer before struct#initialize throws
  if exists('g:workflow_metadata_indexers')
    unlet g:workflow_metadata_indexers
  endif

  function! DummyIndexer()
    return {}
  endfunction

  call AssertThrows(function('struct#metadata#register_viml_indexer', ['dummy_indexer', function('DummyIndexer')]),
        \ "Can't register indexer before Workflow.vim has finished initialization")
endfunction

" TODO
" - atomic update tests
"   - needs planning
" - registering bash indexers
" - executing bash indexers
" - WTF AM I GOING TO DO ABOUT FILE DELETES?!
