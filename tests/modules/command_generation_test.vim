function! TestBasicCommandGeneration()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Daily': {
        \     'root': 'daily/',
        \     'ext': 'md',
        \     'title_format': '%Y-%m-%d',
        \   },
        \ })

  " Test no-argument command
  call Assert(exists(':Daily') == 2, "Command ':Daily' should be defined")
  if exists(':Daily')
    Daily
    call AssertEqual(g:test_workspace . '/RepoRoot/daily/' . strftime('%Y-%m-%d') . '.md', bufname('%'),
          \ "File opened by ':Daily' command is incorrect")
  endif
  call AssertThrows('Daily foo', 'Unexpected argument: foo',
        \ "Command ':Daily' should throw an error when unexpected arguments are provided")
endfunction

function! TestCommandWithTwoMandatoryVariables()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Project': {
        \     'root': 'projects/',
        \     'ext': 'txt',
        \     'title_format': '$client - $project',
        \   },
        \ })

  " Test command with two mandatory variables
  call Assert(exists(':Project') == 2, "Command ':Project' should be defined")
  if exists(':Project')
    Project --client Acme --project Website Redesign
    call AssertEqual(g:test_workspace . '/RepoRoot/projects/Acme - Website Redesign.txt', bufname('%'),
          \ "File opened by ':Project' command with variables is incorrect")
  endif
  call AssertThrows('Project --client Acme', 'Missing mandatory variable: --project',
        \ "Command ':Project' should throw an error when mandatory variable is missing")
endfunction

function! TestCommandWithMandatoryAndOptionalVariables()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Meeting': {
        \     'root': 'meeting/',
        \     'ext': 'md',
        \     'title_format': '$subject - $company?',
        \   },
        \ })
  " Test command with one mandatory and one optional variable
  call Assert(exists(':Meeting') == 2, "Command ':Meeting' should be defined")
  if exists(':Meeting')
    Meeting --subject Quarterly Review
    call AssertEqual(g:test_workspace . '/RepoRoot/meeting/Quarterly Review.md', bufname('%'),
          \ "File opened by ':Meeting' command with one optional variable is incorrect")
    Meeting --subject Quarterly Review --company Globex
    call AssertEqual(g:test_workspace . '/RepoRoot/meeting/Quarterly Review - Globex.md', bufname('%'),
          \ "File opened by ':Meeting' command with both variables is incorrect")
  endif
endfunction

function! TestCommandWithUnexpectedVariable()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Project': {
        \     'root': 'projects/',
        \     'ext': 'txt',
        \     'title_format': '$client - $project',
        \   },
        \ })

  " Test unexpected variable
  call AssertThrows('Project --client Acme --project Website --extra Var', 'Unexpected variable: --extra',
        \ "Command ':Project' should throw an error when unexpected variable is provided")
endfunction

function! TestCommandWithSingleVariableShortcut()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Note': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'title_format': '$title',
        \   },
        \ })

  " Test command with single variable using shortcut syntax
  call Assert(exists(':Note') == 2, "Command ':Note' should be defined")
  if exists(':Note')
    Note Meeting Notes
    call AssertEqual(g:test_workspace . '/RepoRoot/notes/Meeting Notes.md', bufname('%'),
          \ "File opened by ':Note' command with single variable is incorrect")
  endif
  call AssertThrows('Note', 'Missing mandatory variable: --title',
        \ "Command ':Note' should throw an error when mandatory variable is missing")
endfunction

function! TestCommandCompletion()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Task': {
        \     'root': 'tasks/',
        \     'ext': 'md',
        \     'title_format': '$task_name - $due_date?',
        \   },
        \ })

  call Assert(exists('*StructAutogen_complete_Task') == 1,
        \ "Completion function for ':Task' command should be defined")
  if exists('*StructAutogen_complete_Task')
    let completions = StructAutogen_complete_Task('--', '--', 2)
    call AssertEqual(sort(['--task_name', '--due_date']), sort(completions),
          \ "Completion function for ':Task' command returned incorrect completions for --")

    let completions = StructAutogen_complete_Task('--t', '--t', 3)
    call AssertEqual(sort(['--task_name']), sort(completions),
          \ "Completion function for ':Task' command returned incorrect completions for --t")


  endif
endfunction
