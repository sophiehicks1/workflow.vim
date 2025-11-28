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
  call struct#metadata#cleanup_job()
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
  call struct#metadata#cleanup_job()
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
  let locked_files = struct#metadata#lock_files(['notes/Note1.md', 'notes/Note2.md'], v:false)
  let expected_locked_files = [
        \ g:workflow_metadata_jobstate_dir . '/test/notes/Note1.md',
        \ g:workflow_metadata_jobstate_dir . '/test/notes/Note2.md'
        \ ]
  call AssertEqual(expected_locked_files, locked_files, 'Locked files should match expected paths')
  for file in expected_locked_files
    call AssertFileExists(file, 'Locked file should exist: ' . file)
  endfor
  call struct#metadata#cleanup_job()

  " locking files without initializing job state will throw
  call AssertThrows(function('struct#metadata#lock_files', [['notes/Note1.md'], v:false]),
        \ 'No job initialized.')

  " locking files for a non existent job id will throw
  let g:workflow_current_job_id = 'nonexistent'
  call AssertThrows(function('struct#metadata#lock_files', [['notes/Note1.md'], v:false]),
        \ 'Job does not exist: nonexistent')
  unlet g:workflow_current_job_id
endfunction

" test that locking a non existent file will behave as expected
function! TestLockingNonExistentFileThrows()
  " Locking a non existent file throws
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })
  call struct#metadata#initialize_job('test')

  " with continue=false, we should be able to create the lock
  let locked_files = struct#metadata#lock_files(['notes/NoteThatDoesntExist.md'], v:false)
  let expected_locked_files = [
        \ g:workflow_metadata_jobstate_dir . '/test/notes/NoteThatDoesntExist.md',
        \ ]
  call AssertEqual(expected_locked_files, locked_files, 'Locked files should match expected paths even if the source file does not exist')
  for file in expected_locked_files
    call AssertFileExists(file, 'Locked file should exist even if source file does not: ' . file)
  endfor

  " with continue=true, we should get an empty list back
  let locked_files_continue = struct#metadata#lock_files(['notes/AnotherNonExistentFile.md'], v:true)
  call AssertEqual([], locked_files_continue, 'Locking non-existent file with continue=true should return empty list')

  call struct#metadata#cleanup_job()
endfunction

function! TestLockCollisionThrowsWithContinueIsFalse()
  " Locking a file with continue set to false throws and deletes the copy if
  " another job already has that file locked
  " Create a repo to work with (backed by data in tests/data/MetadataTestRepo)
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })
  " Initialize job state for first job
  call struct#metadata#initialize_job('job1')

  " Job1 locks Note1.md and Task1.txt
  let locked_files_job1 = struct#metadata#lock_files(['notes/Note1.md', 'tasks/Task1.txt'], v:false)
  let expected_locked_files_job1 = [
        \ g:workflow_metadata_jobstate_dir . '/job1/notes/Note1.md',
        \ g:workflow_metadata_jobstate_dir . '/job1/tasks/Task1.txt'
        \ ]
  call AssertEqual(expected_locked_files_job1, locked_files_job1, 'Job1 locked files should match expected paths')

  " Initialize job state for second job. N.B. THIS IS NOT A VALID USAGE PATTERN!
  " Jobs set the current job id in global state, so they 
  call struct#metadata#initialize_job('job2')


  " Job2 attempts to lock Note1.md with continue=false, which should throw
  call AssertThrows(function('struct#metadata#lock_files', [['notes/Note1.md', 'notes/Note2.md'], v:false]),
        \ 'Lock conflict for the following files: notes/Note1.md')

  " clean up
  call struct#metadata#cleanup_job()
  " manually clean up job1 since job2's cleanup won't do it
  call delete(g:workflow_metadata_jobstate_dir . '/job1', 'rf')

endfunction

function! TestLockCollisionCanContinueWithContinueIsTrue()
  " Locking a file with continue set to true allows locking other files even
  " if some are already locked by another job
  " Create a repo to work with (backed by data in tests/data/MetadataTestRepo)
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " Job1 locks Note1.md and Task1.txt
  call struct#metadata#initialize_job('job1')
  let locked_files_job1 = struct#metadata#lock_files(['notes/Note1.md', 'tasks/Task1.txt'], v:false)
  let expected_locked_files_job1 = [
        \ g:workflow_metadata_jobstate_dir . '/job1/notes/Note1.md',
        \ g:workflow_metadata_jobstate_dir . '/job1/tasks/Task1.txt'
        \ ]
  call AssertEqual(expected_locked_files_job1, locked_files_job1, 'Job1 locked files should match expected paths')

  " Job2 attempts to lock Note1.md and Note2.md with continue=true
  call struct#metadata#initialize_job('job2')
  let locked_files_job2 = struct#metadata#lock_files(['notes/Note1.md', 'notes/Note2.md'], v:true)
  let expected_locked_files_job2 = [
        \ g:workflow_metadata_jobstate_dir . '/job2/notes/Note2.md'
        \ ]
  call AssertEqual(expected_locked_files_job2, locked_files_job2, 'Job2 should only lock Note2.md successfully')

  " clean up
  call struct#metadata#cleanup_job()
  call delete(g:workflow_metadata_jobstate_dir . '/job1', 'rf')
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
  Page NewNoteWithWords
  call append(0, 'foo bar')
  call append(1, 'baz')
  3d
  write

  let expected_timestamp = systemlist('stat -c %Y ' . shellescape(expand('%:p')))[0]

  " Run the indexer on the current buffer
  let results = struct#metadata#run_indexer('word_indexer')
  " This is needed, because _normally_ the indexer adds __source_file relative
  " to the JOB DIR because we're operating on locked copies of the files. Here,
  " we're just working on the files directly, so we need to adjust the paths.
  function! AbsPath(rel_path)
    return g:test_workspace . '/MetadataTestRepo/' . a:rel_path
  endfunction
  let expected_results = {'words': [
        \ {'word': 'foo', 'line': 1,
        \  '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \ {'word': 'bar', 'line': 1,
        \  '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \ {'word': 'baz', 'line': 2,
        \  '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \ ]}
  call AssertDeepEqual(expected_results, results, 'Indexer should extract words from the buffer correctly')

  " Clean up
  bd!
  call delete(g:test_workspace . '/MetadataTestRepo/notes/NewNoteWithWords.md')
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
  Page NewNoteWithWords
  call append(0, 'foo bar')
  call append(1, 'baz')
  3d
  write

  let expected_timestamp = systemlist('stat -c %Y ' . shellescape(expand('%:p')))[0]

  " Run the indexers on the current buffer
  let results = struct#metadata#run_all_indexers()
  " This is needed, because _normally_ the indexer adds __source_file relative
  " to the JOB DIR because we're operating on locked copies of the files. Here,
  " we're just working on the files directly, so we need to adjust the paths.
  function! AbsPath(rel_path)
    return g:test_workspace . '/MetadataTestRepo/' . a:rel_path
  endfunction
  let expected_results = {
        \ 'words': [
        \   {'word': 'oof', 'line': 1,
        \    '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'title_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'rab', 'line': 1,
        \    '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'title_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'zab', 'line': 2,
        \    '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'title_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'foo', 'line': 1,
        \    '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'bar', 'line': 1,
        \    '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \   {'word': 'baz', 'line': 2,
        \    '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'word_indexer', '__timestamp': expected_timestamp},
        \ ],
        \ 'titles': [
        \   {'title': 'foo bar',
        \    '__source_file': AbsPath('notes/NewNoteWithWords.md'), '__indexer': 'title_indexer', '__timestamp': expected_timestamp},
        \ ]
        \ }
  call AssertDeepEqual(expected_results, results, 'Indexers should aggregate results from multiple indexers correctly')
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

function! TestAtomicIndexUpdateFunction()
  call struct#initialize(g:test_workspace . '/MetadataTestRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ })
  " Define a simple word indexer
  function! WordIndexer()
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

  " Register the indexer
  call struct#metadata#register_viml_indexer('word_indexer', function('WordIndexer'))

  call struct#metadata#index_files(1, ['notes/ExistingNoteWithWords.md', 'notes/AnotherNoteWithWords.md'])

  " Verify the metadata file was created and contains expected data
  let metadata_file = g:test_workspace . '/MetadataTestRepo/.metadata/words.csv'
  call AssertFileExists(metadata_file, 'Metadata file should be created after indexing')
  let csv_results = struct#csv#read_file(metadata_file)

  " Compare the words extracted
  let csv_result_words = map(deepcopy(csv_results), {idx, val -> val.word})
  let expected_words = ['Lorem', 'ipsum', 'dolor', 'Sit', 'amet', 'Foo', 'bar', 'baz']
  call AssertDeepEqual(sort(expected_words), sort(csv_result_words), 'Indexed words should match expected words')

  " Compare the headings
  let actual_headers = keys(csv_results[0])

  let expected_headers = sort(['word', 'line', '__source_file', '__indexer', '__timestamp'])
  call AssertDeepEqual(expected_headers, sort(actual_headers), 'CSV headers should match expected headers')
endfunction

function! TestBackgroundIndexAndDeleteBacklog()
  call struct#initialize(g:test_workspace . '/BackgroundIndexingRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ })

  function! WordIndexer()
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

  call struct#metadata#register_viml_indexer('word_indexer', function('WordIndexer'))

  " Initial indexing to set baseline
  sleep 1
  call struct#metadata#index_files(1, ['notes/Foobar.md', 'notes/Lipsum.md'])
  sleep 1

  " check that the backlog is empty initially
  let backlog = struct#metadata#indexing_backlog()
  call AssertEqual([], backlog.to_index, 'Initial backlog should be empty')

  " Create a new file and check that the backlog contains the new file
  Page NewFoobar
  call append(0, 'Foofoo barbar bazbaz')
  write
  let backlog = struct#metadata#indexing_backlog()
  let expected_backlog = ['notes/NewFoobar.md']
  call AssertEqual(expected_backlog, backlog.to_index, 'Backlog should contain the new file')

  " Add some text to an existing file, and check that it appears in the
  " backlog
  Page Foobar
  call append(0, 'Foo bar baz')
  write!
  let backlog = struct#metadata#indexing_backlog()
  let expected_backlog = ['notes/NewFoobar.md', 'notes/Foobar.md']
  call AssertEqual(sort(expected_backlog), sort(backlog.to_index), 'Backlog should contain modified files')

  " Delete a file and check that it appears in the delete backlog
  call delete(g:test_workspace . '/BackgroundIndexingRepo/notes/Lipsum.md')
  let backlog = struct#metadata#indexing_backlog()
  let expected_to_delete = ['notes/Lipsum.md']
  call AssertEqual(expected_to_delete, backlog.to_delete, 'Backlog should contain deleted files')
endfunction

function! TestDeleteFromIndex()
  call struct#initialize(g:test_workspace . '/BackgroundIndexingRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ })

  function! WordIndexer()
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

  call struct#metadata#register_viml_indexer('word_indexer', function('WordIndexer'))

  Page ToBeDeleted
  call append(0, 'This file will be deleted from the index')
  write

  " Initial indexing to set baseline
  call struct#metadata#index_files(1, ['notes/ToBeDeleted.md'])

  " Verify that the file is indexed
  let metadata_file = struct#utils#from_relative_path('.metadata/words.csv')
  let csv_results = struct#csv#read_file(metadata_file)
  let indexed_files = uniq(map(deepcopy(csv_results), {idx, val -> val.__source_file}))
  call Assert(index(indexed_files, 'notes/ToBeDeleted.md') != -1,
        \ 'File should be indexed before deletion')

  " Delete the file from the index
  call struct#metadata#delete_from_index(1, ['notes/ToBeDeleted.md'])

  " Verify that the file is no longer indexed
  let csv_results_after_delete = struct#csv#read_file(metadata_file)
  let indexed_files_after_delete = uniq(map(deepcopy(csv_results_after_delete), {idx, val -> val.__source_file}))
  call Assert(index(indexed_files_after_delete, 'notes/ToBeDeleted.md') == -1,
        \ 'File should be removed from index after deletion')
endfunction

function! TestIndexCompression()
  call struct#initialize(g:test_workspace . '/BackgroundIndexingRepo', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ })

  function! WordIndexer()
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

  call struct#metadata#register_viml_indexer('word_indexer', function('WordIndexer'))
 
  " Confirm that notes/Foobar.md is indexed
  let rows = struct#csv#read_file(struct#utils#from_relative_path('.metadata/words.csv'))
  let foobar_rows = filter(copy(rows), {idx, val -> val.__source_file == 'notes/Foobar.md'})
  let num_foobar_rows_before = len(foobar_rows)
  call Assert(num_foobar_rows_before != 0, 'notes/Foobar.md should be indexed initially')

  " Confirm that there are more rows after indexing again (duplicate entries)
  call struct#metadata#index_files(1, ['notes/Foobar.md'])
  let rows = struct#csv#read_file(struct#utils#from_relative_path('.metadata/words.csv'))
  let foobar_rows = filter(copy(rows), {idx, val -> val.__source_file == 'notes/Foobar.md'})
  let num_foobar_rows_after = len(foobar_rows)
  call Assert(num_foobar_rows_after > num_foobar_rows_before, 'Re-indexing should create duplicate entries')

  " Now, run compression
  call struct#metadata#compress_index(1)
  let rows = struct#csv#read_file(struct#utils#from_relative_path('.metadata/words.csv'))
  let foobar_rows = filter(copy(rows), {idx, val -> val.__source_file == 'notes/Foobar.md'})
  let num_foobar_rows_after_compression = len(foobar_rows)
  call Assert(num_foobar_rows_after_compression <= num_foobar_rows_before,
        \ 'Index compression should reduce the number of entries')
endfunction
