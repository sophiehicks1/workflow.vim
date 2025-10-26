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
  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {'NoRoot': {'ext': 'md'}}]),
        \ 'NoRoot.*root')

  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {'NoExt': {'root': 'notes/'}}]),
        \ 'NoExt.*ext')
endfunction

function! TestVariableValidation()
  " variables must be an dictionary mapping keys like '$foo' or 'bar' to configs if provided
  call AssertDoesNotThrow(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'GoodVars': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': {
        \       'valid_var': {'default': 'value', 'optional': 0},
        \       '$optional_var': {'optional': 1},
        \       'simple_var': {},
        \     },
        \   },
        \ }]),
        \ 'GoodVars with valid variables should not throw an error')

  " variables must be a dictionary
  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'BadVars': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': 'not-a-dictionary',
        \   },
        \ }]), 'BadVars.*variables.*dictionary')

  " variable names must be strings
  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'BadVarName': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': {123: {}},
        \   },
        \ }]), 'BadVarName.*invalid variable.*123')

  " variables must be an dictionary, not an array
  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'BadVarFormat': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': ['valid_var', 'another_var'],
        \   },
        \ }]), 'BadVarFormat.*variables.*dictionary')

  " variables should only contain alphanumeric characters, underscores, $ and ?
  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'InvalidVarChars': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': {'in*valid': {}},
        \   },
        \ }]), 'InvalidVarChars.*invalid variable.*in\*valid')
endfunction

function! TestVariableConfigStructure()
  " variables must be dictionaries if provided
  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'BadVarConfig': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': {'valid_var': 'not-a-dictionary'},
        \   },
        \ }]), 'BadVarConfig.*variable.*dictionary')

  " variable config dictionaries can be empty
  call AssertDoesNotThrow(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'EmptyVarConfig': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': {'valid_var': {}},
        \   },
        \ }]),
        \ 'EmptyVarConfig with empty variable config should not throw an error')

  " variable config can have 'default' and 'optional' keys
  call AssertDoesNotThrow(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'FullVarConfig': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': {
        \       'var_with_default': {'default': 'value'},
        \       'optional_var': {'optional': 1},
        \     },
        \   },
        \ }]),
        \ 'FullVarConfig with valid variable config should not throw an error')

  " variable config cannot have unknown keys
  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'UnknownVarConfig': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': {
        \       'var_with_unknown_key': {'unknown_key': 'value'},
        \     },
        \   },
        \ }]), 'UnknownVarConfig.*invalid key.*unknown_key')

  " variable 'optional' key must be a boolean 0 or 1
  call AssertThrows(function('struct#initialize', [g:test_workspace . '/RepoRoot', {
        \   'InvalidOptionalVar': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'variables': {
        \       'var_with_invalid_optional': {'optional': 'yes'},
        \     },
        \   },
        \ }]), 'InvalidOptionalVar.*optional.*Boolean')
endfunction

function! TestRepositoryRootValidation()
  " repository root must be an absolute path
  call AssertThrows(function('struct#initialize', ['relative/path', {'Page': {'root': 'notes/', 'ext': 'md'}}]),
        \ 'Repository root.*absolute path')
  " should not create directories when given a path that fails validation
  call AssertDirNotExists('relative/path')

  " repository root is created if it does not exist
  call AssertDirNotExists(g:test_workspace . '/RepoRootNew')
  call struct#initialize(g:test_workspace . '/RepoRootNew', {'Page': {'root': 'notes/', 'ext': 'md'}})
  call AssertDirExists(g:test_workspace . '/RepoRootNew')

  " repository root must be a directory
  let not_a_dir = g:test_workspace . '/RepoRoot/notes/Page.md'
  call mkdir(g:test_workspace . '/RepoRoot/notes', 'p')
  call writefile(['# A note'], not_a_dir)
  call AssertThrows(function('struct#initialize', [not_a_dir, {'Page': {'root': 'notes/', 'ext': 'md'}}]),
        \ 'Repository root.*directory')
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

  " title formats must contain static text or at least one non-optional
  " variable, optional variable with default or date component
  call AssertThrows(
        \ function('struct#initialize', [
        \   g:test_workspace . '/RepoRoot',
        \   {
        \     'EmptyTitle': {
        \       'root': 'empty/',
        \       'ext': 'md',
        \       'title_format': '$optional_var?',
        \     },
        \   }
        \ ]),
        \ 'Title format must contain static text, a non-optional variable, a variable with default '
        \ . 'or a date component')
endfunction

function! TestVariableNormalizationWithOnlyTitleVariables()
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
endfunction

function! TestVariableNormalizationWithMixedVariables()
  " workflows with both title_format and additional variables are normalized
  " correctly
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Project': {
        \     'root': 'projects/',
        \     'ext': 'txt',
        \     'title_format': '$client - $project',
        \     'variables': {'due_date': {'optional': 1}},
        \   },
        \ })
  let expected_variables_proj = {
        \ 'client': {'optional': 0},
        \ 'project': {'optional': 0},
        \ 'due_date': {'optional': 1},
        \ }
  call AssertDeepEqual(expected_variables_proj, g:struct_workflows['Project'].variables,
        \ 'Workflows with both title_format and additional variables are normalized correctly')
endfunction

function! TestVariableNormalizationWithNoVariables()
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
endfunction

function! TestVariableNormalizationDollarSyntaxIsOptional()
  " $ in variable names is optional in the variables list
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Task': {
        \     'root': 'tasks/',
        \     'ext': 'txt',
        \     'title_format': '$task_name',
        \     'variables': {'$due_date': {'optional': 1}},
        \   },
        \ })
  let expected_variables_task = {
        \ 'task_name': {'optional': 0},
        \ 'due_date': {'optional': 1},
        \ }
  call AssertDeepEqual(expected_variables_task, g:struct_workflows['Task'].variables,
        \ '$ in variable names is optional in the variables list')
endfunction

function! TestVariableNormalizationWithConflicts()
  " conflicts between title_format and variables are caught and thrown
  call AssertDoesNotThrow(
        \ function('struct#initialize', [
        \   g:test_workspace . '/RepoRoot',
        \   {
        \     'Event': {
        \       'root': 'events/',
        \       'ext': 'md',
        \       'title_format': '$event_name - $location?',
        \       'variables': {'location': {'optional': 1}},
        \     },
        \   }
        \ ]),
        \ 'No conflict between title_format and variables for "event_name" should not throw an error')
  call AssertThrows(
        \ function('struct#initialize', [
        \   g:test_workspace . '/RepoRoot',
        \   {
        \     'Appointment': {
        \       'root': 'appointments/',
        \       'ext': 'md',
        \       'title_format': '$client - $date?',
        \       'variables': {'$date': {'optional': 0}},
        \     },
        \   }
        \ ]),
        \ 'Conflict in variable configuration for "date" between title_format and variables config')
  call AssertThrows(
        \ function('struct#initialize', [
        \   g:test_workspace . '/RepoRoot',
        \   {
        \     'Appointment': {
        \       'root': 'appointments/',
        \       'ext': 'md',
        \       'title_format': '$client - $date',
        \       'variables': {'$date': {'optional': 1}},
        \     },
        \   }
        \ ]),
        \ 'Conflict in variable configuration for "date" between title_format and variables config')
endfunction

function! TestVariableDefaultMerging()
  " if a default is set for a variable that is optional in the title_format,
  " and optional is not set in the variables config, the configs are merged
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Reminder': {
        \     'root': 'reminders/',
        \     'ext': 'txt',
        \     'title_format': '$message?',
        \     'variables': {'message': {'default': 'No message'}},
        \   },
        \ })
  let expected_variables_reminder = {
        \ 'message': {'optional': 1, 'default': 'No message'},
        \ }
  call AssertDeepEqual(expected_variables_reminder, g:struct_workflows['Reminder'].variables,
        \ 'Default set for optional title_format variable merges correctly with variables config')
endfunction

function! TestWorkflowRootValidation()
  " workflow root must be a subdirectory of the repository root
  call AssertThrows(
        \ function('struct#initialize', [
        \   g:test_workspace . '/RepoRoot',
        \   {
        \     'OutsideRoot': {
        \       'root': '../outside/',
        \       'ext': 'md',
        \     },
        \   }
        \ ]),
        \ 'Workflow "OutsideRoot" root ".*" is outside repository root ".*"')
endfunction
