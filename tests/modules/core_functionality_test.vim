function! TestWorkflowInitialization()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Page': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \   },
        \ })
  let l:page = g:struct_workflows['Page']

  " workflows can have a file extension configured
  call AssertEqual('md', l:page['ext'],
        \ 'Workflows can be configured with a file extension')

  " workflows have an absolute path for their root
  let l:expected_root = expand(g:test_workspace . '/RepoRoot/notes/', ':p')
  call AssertEqual(l:expected_root, l:page['root'],
        \ 'Workflows have an absolute path for their root')
endfunction

function! TestWorkflowInitializationErrors()
  " create the RepoRoot directory for testing
  call mkdir(g:test_workspace . '/RepoRoot', 'p')

  " file extension and root are both mandatory
  let l:args = [g:test_workspace . '/RepoRoot', {'NoRoot': {'ext': 'md'}}]
  call AssertThrows(function('struct#initialize', l:args), 'NoRoot.*root')

  let l:args = [g:test_workspace . '/RepoRoot', {'NoExt': {'root': 'notes/'}}]
  call AssertThrows(function('struct#initialize', l:args), 'NoExt.*ext')
endfunction

function! TestRepositoryRootValidation()
  " repository root must be an absolute path
  let l:args = ['relative/path', {'Page': {'root': 'notes/', 'ext': 'md'}}]
  call AssertThrows(function('struct#initialize', l:args), 'Repository root.*absolute path')
  " should not create directories when given a path that fails validation
  call AssertDirNotExists('relative/path')

  " repository root is created if it does not exist
  call AssertDirNotExists(g:test_workspace . '/RepoRootNew')
  let l:args = [g:test_workspace . '/RepoRootNew', {'Page': {'root': 'notes/', 'ext': 'md'}}]
  call struct#initialize(l:args[0], l:args[1])
  call AssertDirExists(g:test_workspace . '/RepoRootNew')

  " repository root must be a directory
  let not_a_dir = g:test_workspace . '/RepoRoot/notes/Page.md'
  call mkdir(g:test_workspace . '/RepoRoot/notes', 'p')
  call writefile(['# A note'], not_a_dir)
  let l:args = [not_a_dir, {'Page': {'root': 'notes/', 'ext': 'md'}}]
  call AssertThrows(function('struct#initialize', l:args), 'Repository root.*directory')
endfunction

function! TestFileOpen()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " test that it opens the right file
  let l:filepath = g:test_workspace . '/RepoRoot/notes/NewNote.md'
  call AssertFileNotExists(l:filepath)
  call struct#open_path(l:filepath)
  call AssertBufferName('NewNote.md', 'struct#open_path opens the path in the current buffer')
  call AssertBufferInDirectory(g:test_workspace . '/RepoRoot/notes',
        \ 'struct#open_path opens the file in the correct directory')

  " test that it throws if no workflow matches
  call AssertThrows(function('struct#open_path', [g:test_workspace . '/RepoRoot/other/NewFile.xyz']),
        \ 'No matching workflow found for path')
  " test that it throws if the file extension does not match
  call AssertThrows(function('struct#open_path', [g:test_workspace . '/RepoRoot/notes/NewNote.txt']),
        \ 'File matched workflow Page, but extension txt does not match expected extension md')
  " test that it creates parent directories as needed
  let l:deep_filepath = g:test_workspace . '/RepoRoot/notes/subdir1/subdir2/DeepNote.md'
  call AssertFileNotExists(l:deep_filepath)
  call struct#open_path(l:deep_filepath)
  call AssertDirExists(g:test_workspace . '/RepoRoot/notes/subdir1/subdir2',
        \ 'struct#open_path creates parent directories as needed')
endfunction

function! TestWorkflowResolution()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ })

  " test that it resolves the right workflow
  let l:note_path = g:test_workspace . '/RepoRoot/notes/NewNote.md'
  call AssertEqual('Page', struct#resolve_workflow(l:note_path),
        \ 'struct#resolve_workflow resolves the correct workflow for a note')

  " test that it throws if no workflow matches
  call AssertThrows(function('struct#resolve_workflow', [g:test_workspace . '/RepoRoot/other/NewFile.xyz']),
        \ 'No matching workflow found for path')

  " test that it resolves the most specific workflow
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {'root': 'notes/', 'ext': 'md'},
        \ 'Task': {'root': 'tasks/', 'ext': 'txt'},
        \ 'SubNote': {'root': 'notes/sub/', 'ext': 'md'},
        \ })
  let l:subnote_path = g:test_workspace . '/RepoRoot/notes/sub/SubNote.md'
  call AssertEqual('SubNote', struct#resolve_workflow(l:subnote_path),
        \ 'struct#resolve_workflow resolves the most specific workflow')

  " test that it throws when the file doesn't matched workflow extension
  let l:note_path = g:test_workspace . '/RepoRoot/notes/NewNote.txt'
  call AssertThrows(function('struct#resolve_workflow', [l:note_path]),
        \ 'File matched workflow Page, but extension txt does not match expected extension md')
endfunction

function! TestTitleFormatParsing()
  " struct#parse_title_format correctly identifies variables
  let title_format = 'Meeting Notes - $client - $subject'
  let parsed = struct#parse_title_format(title_format)
  call AssertEqual(['$client', '$subject'], parsed['variables'],
        \ 'struct#parse_title_format correctly identifies variables in title format')
  call AssertEqual(title_format, parsed['format'],
        \ 'struct#parse_title_format preserves the original title format')

  " struct#parse_title_format correctly identifies optional variables
  let title_format_opt = 'Meeting Notes - $client-$subject?'
  let parsed_opt = struct#parse_title_format(title_format_opt)
  call AssertEqual(['$client', '$subject?'], parsed_opt['variables'],
        \ 'struct#parse_title_format correctly identifies optional variables in title format')
  call AssertEqual(title_format_opt, parsed_opt['format'],
        \ 'struct#parse_title_format preserves the original title format with optional variables')

  " struct#parse_title_format flags when there are date components
  let title_with_date = '%Y-%m-%d Meeting with $client'
  let parsed_date = struct#parse_title_format(title_with_date)
  call AssertEqual(['$client'], parsed_date['variables'],
        \ 'struct#parse_title_format correctly identifies variables when date components are present')
  call AssertEqual(title_with_date, parsed_date['format'],
        \ 'struct#parse_title_format preserves the original title format with date components')
  call Assert(parsed_date['has_date'],
        \ 'struct#parse_title_format flags when there are date components in the title format')
endfunction

function! TestTitleFormatValidation()
  " title formats only consist of [a-zA-z0-9-_%:()&+=?#^] characters
  let title_format = 'My-Title_100: (Test) & More + Info = Yes?'
  call AssertDoesNotThrow(function('struct#parse_title_format', [title_format]),
        \ 'Valid title format should not throw an error')
  let invalid_title_format = 'Invalid Title!'
  call AssertThrows(function('struct#parse_title_format', [invalid_title_format]),
        \ 'Title format contains invalid characters: !')

  " static titles are allowed
  let static_title = 'Static Title'
  call AssertDoesNotThrow(function('struct#parse_title_format', [static_title]),
        \ 'Static title format should not throw an error')
  call AssertDeepEqual({'format': static_title, 'variables': [], 'has_date': 0},
        \ struct#parse_title_format(static_title),
        \ 'struct#parse_title_format correctly parses static title formats')
endfunction

function TestTitleGeneration()
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
  let l:variables = {'$client': 'AcmeCorp', '$subject': 'ProjectX'}
  let l:title = struct#generate_title(l:workflow, l:variables)
  call AssertEqual('Meeting - AcmeCorp - ProjectX.md', l:title,
        \ 'struct#generate_title generates title with all variables provided')

  " generate title with optional variable missing...
  let l:workflow_opt = 'WithOptional'
  let l:variables_opt = {'$client': 'AcmeCorp'}
  let l:title_opt = struct#generate_title(l:workflow_opt, l:variables_opt)
  call AssertEqual('Meeting - AcmeCorp.md', l:title_opt,
        \ 'struct#generate_title generates title with optional variable missing')
  " ... and with optional variable provided
  let l:variables_opt_all = {'$client': 'AcmeCorp', '$subject': 'ProjectX'}
  let l:title_opt_all = struct#generate_title(l:workflow_opt, l:variables_opt_all)
  call AssertEqual('Meeting - AcmeCorp - (ProjectX).md', l:title_opt_all,
        \ 'struct#generate_title generates title with all optional variables provided')

  " generate title with missing required variable should throw
  let l:variables_missing = {'subject': 'ProjectX'}
  call AssertThrows(function('struct#generate_title', [l:workflow, l:variables_missing]),
        \ 'Missing required variable: $client')

  " generate title for static title format
  let l:workflow_static = 'Index'
  let l:title_static = struct#generate_title(l:workflow_static, {})
  call AssertEqual('Index.html', l:title_static,
        \ 'struct#generate_title generates static titles correctly')

  " generate title with date components
  let l:workflow_date = 'Daily'
  let l:title_date = struct#generate_title(l:workflow_date, {})
  let l:expected_date = strftime('%Y-%m-%d') . '.md'
  call AssertEqual(l:expected_date, l:title_date,
        \ 'struct#generate_title generates titles with date components correctly')

  " generate title with date and optional variable missing
  let l:workflow_journal = 'Journal'
  let l:title_journal = struct#generate_title(l:workflow_journal, {})
  let l:expected_journal = strftime('%Y-%m-%d') . '.md'
  call AssertEqual(l:expected_journal, l:title_journal,
        \ 'struct#generate_title generates titles with date and missing optional variable correctly')
  " generate title with date and optional variable provided
  let l:variables_journal = {'$title': 'a journal entry'}
  let l:title_journal_full = struct#generate_title(l:workflow_journal, l:variables_journal)
  let l:expected_journal_full = strftime('%Y-%m-%d') . ' a journal entry.md'
  call AssertEqual(l:expected_journal_full, l:title_journal_full,
        \ 'struct#generate_title generates titles with date and all optional variables correctly')
endfunction
