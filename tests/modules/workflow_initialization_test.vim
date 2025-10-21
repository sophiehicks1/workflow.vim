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

  " workflows have a relative path for their root
  let l:expected_root = expand(g:test_workspace . '/RepoRoot/notes/', ':p')
  call AssertEqual(l:expected_root, l:page['root'],
        \ 'Workflows have an relative path for their root')
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

function! TestTitleFormatParsing()
  " struct#init#parse_title_format correctly identifies variables
  let title_format = 'Meeting Notes - $client - $subject'
  let parsed = struct#init#parse_title_format(title_format)
  call AssertEqual(['$client', '$subject'], parsed['variables'],
        \ 'struct#init#parse_title_format correctly identifies variables in title format')
  call AssertEqual(title_format, parsed['format'],
        \ 'struct#init#parse_title_format preserves the original title format')

  " struct#init#parse_title_format correctly identifies optional variables
  let title_format_opt = 'Meeting Notes - $client-$subject?'
  let parsed_opt = struct#init#parse_title_format(title_format_opt)
  call AssertEqual(['$client', '$subject?'], parsed_opt['variables'],
        \ 'struct#init#parse_title_format correctly identifies optional variables in title format')
  call AssertEqual(title_format_opt, parsed_opt['format'],
        \ 'struct#init#parse_title_format preserves the original title format with optional variables')

  " struct#init#parse_title_format flags when there are date components
  let title_with_date = '%Y-%m-%d Meeting with $client'
  let parsed_date = struct#init#parse_title_format(title_with_date)
  call AssertEqual(['$client'], parsed_date['variables'],
        \ 'struct#init#parse_title_format correctly identifies variables when date components are present')
  call AssertEqual(title_with_date, parsed_date['format'],
        \ 'struct#init#parse_title_format preserves the original title format with date components')
  call Assert(parsed_date['has_date'],
        \ 'struct#init#parse_title_format flags when there are date components in the title format')
endfunction

function! TestTitleFormatValidation()
  " title formats only consist of [a-zA-z0-9-_%:()&+=?#^] characters
  let title_format = 'My-Title_100: (Test) & More + Info = Yes?'
  call AssertDoesNotThrow(function('struct#init#parse_title_format', [title_format]),
        \ 'Valid title format should not throw an error')
  let invalid_title_format = 'Invalid Title!'
  call AssertThrows(function('struct#init#parse_title_format', [invalid_title_format]),
        \ 'Title format contains invalid characters: !')

  " static titles are allowed
  let static_title = 'Static Title'
  call AssertDoesNotThrow(function('struct#init#parse_title_format', [static_title]),
        \ 'Static title format should not throw an error')
  call AssertDeepEqual({'format': static_title, 'variables': [], 'has_date': 0},
        \ struct#init#parse_title_format(static_title),
        \ 'struct#init#parse_title_format correctly parses static title formats')
endfunction

function! TestVariableNormalization()
  " workflows with only title_format variables are normalized correctly
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Meeting': {
        \     'root': 'meeting/',
        \     'ext': 'md',
        \     'title_format': 'Meeting - $client - $subject?',
        \   },
        \ })
  let expected_variables = {
        \ 'client': {'optional': 0},
        \ 'subject': {'optional': 1},
        \ }
  call AssertDeepEqual(expected_variables, g:struct_workflows['Meeting'].variables,
        \ 'Workflows with only title_format variables are normalized correctly')

  " workflows with both title_format and additional variables are normalized
  " correctly
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Project': {
        \     'root': 'projects/',
        \     'ext': 'txt',
        \     'title_format': '$client - $project',
        \     'variables': ['$due_date?'],
        \   },
        \ })
  let expected_variables_proj = {
        \ 'client': {'optional': 0},
        \ 'project': {'optional': 0},
        \ 'due_date': {'optional': 1},
        \ }
  call AssertDeepEqual(expected_variables_proj, g:struct_workflows['Project'].variables,
        \ 'Workflows with both title_format and additional variables are normalized correctly')

  " workflows with no variables have an empty variables object
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Index': {
        \     'root': 'index/',
        \     'ext': 'html',
        \     'title_format': 'Index',
        \   },
        \ })
  call AssertDeepEqual({}, g:struct_workflows['Index'].variables,
        \ 'Workflows with no variables have an empty variables object')

  " optional variables in titles are correctly identified
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Journal': {
        \     'root': 'journal/',
        \     'ext': 'md',
        \     'title_format': '%Y-%m-%d $title?',
        \   },
        \ })
  let expected_variables_journal = {
        \ 'title': {'optional': 1},
        \ }
  call AssertDeepEqual(expected_variables_journal, g:struct_workflows['Journal'].variables,
        \ 'Optional variables in titles are correctly identified')

  " $ in variable names is optional in the variables list
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Task': {
        \     'root': 'tasks/',
        \     'ext': 'txt',
        \     'title_format': '$task_name',
        \     'variables': ['due_date?'],
        \   },
        \ })
  let expected_variables_task = {
        \ 'task_name': {'optional': 0},
        \ 'due_date': {'optional': 1},
        \ }
  call AssertDeepEqual(expected_variables_task, g:struct_workflows['Task'].variables,
        \ '$ in variable names is optional in the variables list')
endfunction
