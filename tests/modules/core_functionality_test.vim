function! TestFileOpen()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " test that it opens the right file
  let l:filepath = g:test_workspace . '/RepoRoot/notes/NewNote.md'
  call AssertFileNotExists(l:filepath)
  call struct#open#open_path(l:filepath)
  call AssertBufferName('NewNote.md', 'struct#open#open_path opens the path in the current buffer')
  call AssertBufferInDirectory(g:test_workspace . '/RepoRoot/notes',
        \ 'struct#open#open_path opens the file in the correct directory')

  " test that it throws if no workflow matches
  call AssertThrows(function('struct#open#open_path', [g:test_workspace . '/RepoRoot/other/NewFile.xyz']),
        \ 'No matching workflow found for path')

  " test that it throws if the file extension does not match
  call AssertThrows(function('struct#open#open_path', [g:test_workspace . '/RepoRoot/notes/NewNote.txt']),
        \ 'File matched workflow Page, but extension txt does not match expected extension md')

  " test that it creates parent directories as needed
  let l:deep_filepath = g:test_workspace . '/RepoRoot/notes/subdir1/subdir2/DeepNote.md'
  call AssertFileNotExists(l:deep_filepath)
  call struct#open#open_path(l:deep_filepath)
  call AssertDirExists(g:test_workspace . '/RepoRoot/notes/subdir1/subdir2',
        \ 'struct#open#open_path creates parent directories as needed')

  " test that it throws if the file extension does not match the workflow
  let l:wrong_ext_filepath = g:test_workspace . '/RepoRoot/tasks/Task1.md'
  call AssertThrows(function('struct#open#open_path', [l:wrong_ext_filepath]),
        \ 'File matched workflow Task, but extension md does not match expected extension txt')
endfunction

function! TestWorkflowResolution()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " test that it resolves the right workflow
  let l:note_path = g:test_workspace . '/RepoRoot/notes/NewNote.md'
  call AssertEqual('Page', struct#utils#resolve_workflow(l:note_path),
        \ 'struct#utils#resolve_workflow resolves the correct workflow for a note')

  " test that it throws if no workflow matches
  call AssertThrows(function('struct#utils#resolve_workflow', [g:test_workspace . '/RepoRoot/other/NewFile.xyz']),
        \ 'No matching workflow found for path')

  " test that it resolves the most specific workflow
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ 'SubNote': {'root': 'notes/sub/', 'ext': 'md'},
        \ })
  let l:subnote_path = g:test_workspace . '/RepoRoot/notes/sub/SubNote.md'
  call AssertEqual('SubNote', struct#utils#resolve_workflow(l:subnote_path),
        \ 'struct#utils#resolve_workflow resolves the most specific workflow')
endfunction

function! TestTitleGeneration()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Meeting': {
        \   'root': 'meetings/',
        \   'ext': 'md',
        \   'title_format': 'Meeting - $client - $subject',
        \ },
        \ 'WithOptional': {
        \   'root': 'optional/',
        \   'ext': 'md',
        \   'title_format': 'Meeting - $client - ($subject?)',
        \ },
        \ 'Daily': {
        \   'root': 'daily/',
        \   'ext': 'md',
        \   'title_format': '%Y-%m-%d',
        \ },
        \ 'Journal': {
        \   'root': 'journal/',
        \   'ext': 'md',
        \   'title_format': '%Y-%m-%d $title?',
        \ },
        \ 'Index': {
        \    'root': './',
        \    'ext': 'html',
        \    'title_format': 'Index',
        \ },
        \ })
  let l:workflow = 'Meeting'
  let l:config = g:struct_workflows[l:workflow]

  " generate title with all variables provided
  let l:variables = {'client': 'AcmeCorp', 'subject': 'ProjectX'}
  let l:title = struct#open#generate_title(l:workflow, l:variables)
  call AssertEqual('Meeting - AcmeCorp - ProjectX.md', l:title,
        \ 'struct#open#generate_title generates title with all variables provided')

  " generate title with optional variable missing...
  let l:workflow_opt = 'WithOptional'
  let l:variables_opt = {'client': 'AcmeCorp'}
  let l:title_opt = struct#open#generate_title(l:workflow_opt, l:variables_opt)
  call AssertEqual('Meeting - AcmeCorp.md', l:title_opt,
        \ 'struct#open#generate_title generates title with optional variable missing')
  " ... and with optional variable provided
  let l:variables_opt_all = {'client': 'AcmeCorp', 'subject': 'ProjectX'}
  let l:title_opt_all = struct#open#generate_title(l:workflow_opt, l:variables_opt_all)
  call AssertEqual('Meeting - AcmeCorp - (ProjectX).md', l:title_opt_all,
        \ 'struct#open#generate_title generates title with all optional variables provided')

  " generate title with missing required variable should throw
  let l:variables_missing = {'subject': 'ProjectX'}
  call AssertThrows(function('struct#open#generate_title', [l:workflow, l:variables_missing]),
        \ 'Missing required variable: client')

  " generate title for static title format
  let l:workflow_static = 'Index'
  let l:title_static = struct#open#generate_title(l:workflow_static, {})
  call AssertEqual('Index.html', l:title_static,
        \ 'struct#open#generate_title generates static titles correctly')

  " generate title with date components
  let l:workflow_date = 'Daily'
  let l:title_date = struct#open#generate_title(l:workflow_date, {})
  let l:expected_date = strftime('%Y-%m-%d') . '.md'
  call AssertEqual(l:expected_date, l:title_date,
        \ 'struct#open#generate_title generates titles with date components correctly')

  " generate title with date and optional variable missing
  let l:workflow_journal = 'Journal'
  let l:title_journal = struct#open#generate_title(l:workflow_journal, {})
  let l:expected_journal = strftime('%Y-%m-%d') . '.md'
  call AssertEqual(l:expected_journal, l:title_journal,
        \ 'struct#open#generate_title generates titles with date and missing optional variable correctly')
  " generate title with date and optional variable provided
  let l:variables_journal = {'title': 'a journal entry'}
  let l:title_journal_full = struct#open#generate_title(l:workflow_journal, l:variables_journal)
  let l:expected_journal_full = strftime('%Y-%m-%d') . ' a journal entry.md'
  call AssertEqual(l:expected_journal_full, l:title_journal_full,
        \ 'struct#open#generate_title generates titles with date and all optional variables correctly')
endfunction

function! TestFileOpenWithFilenameGeneration()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Meeting': {
        \   'root': 'meetings/',
        \   'ext': 'md',
        \   'title_format': '%Y-%m-%d - $client - $subject',
        \ },
        \ })

  " open file with generated filename
  call struct#open('Meeting', {'$client': 'AcmeCorp', '$subject': 'ProjectX'})
  let l:expected_filename = strftime('%Y-%m-%d') . ' - AcmeCorp - ProjectX.md'
  call AssertBufferName(l:expected_filename,
        \ 'struct#open generates filename from title format and opens it')
  call AssertBufferInDirectory(g:test_workspace . '/RepoRoot/meetings',
        \ 'struct#open opens the file in the correct directory')

  " open file with missing required variable should throw
  call AssertThrows(function('struct#open', ['Meeting', {'$client': 'AcmeCorp'}]),
        \ 'Missing required variable: subject')

  " open file with invalid workflow should throw
  call AssertThrows(function('struct#open', ['NonExistentWorkflow', {}]),
        \ 'No such workflow: NonExistentWorkflow')

  " open file works with or without $ prefix
  call struct#open('Meeting', {'client': 'BetaCorp', 'subject': 'ProjectY'})
  let l:expected_filename2 = strftime('%Y-%m-%d') . ' - BetaCorp - ProjectY.md'
  call AssertBufferName(l:expected_filename2,
        \ 'struct#open works with variable names with or without $ prefix')
endfunction
