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

  call Assert(exists('*StructAutogen_complete_Task_Create') == 1,
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

function! TestWorkflowFileListFilter()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Page': {
        \     'root': './',
        \     'ext': 'md',
        \     'title_format': '$title',
        \   },
        \   'Note': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'title_format': '$title',
        \   },
        \   'Log': {
        \     'root': 'logs/',
        \     'ext': 'txt',
        \     'title_format': '%Y-%m-%d',
        \   },
        \ })

  " Create test files
  call s:create_file('PageOne.md', ['# Page One'])
  call s:create_file('notes/NoteOne.md', ['# Note One'])
  call s:create_file('logs/2024-06-01.txt', ['Log Entry 1'])
  call s:create_file('logs/2024-06-02.txt', ['Log Entry 2'])

  let all_files = struct#utils#all_repo_files()
  let note_files = struct#utils#filter_files_by_workflow(all_files, 'Note')
  call AssertEqual([ 'notes/NoteOne.md' ], note_files,
        \ "Filtering files for 'Note' workflow returned incorrect results")
  let page_files = struct#utils#filter_files_by_workflow(all_files, 'Page')
  call AssertEqual([ 'PageOne.md' ], page_files,
        \ "Filtering files for 'Page' workflow returned incorrect results")

  " Clean up test files
  call delete(g:test_workspace . '/RepoRoot/PageOne.md')
  call delete(g:test_workspace . '/RepoRoot/notes/NoteOne.md')
  call delete(g:test_workspace . '/RepoRoot/logs/2024-06-01.txt')
  call delete(g:test_workspace . '/RepoRoot/logs/2024-06-02.txt')
endfunction

function! s:create_file(relative_path, content)
  call mkdir(fnamemodify(a:relative_path, ':h'), 'p')
  let filepath = g:test_workspace . '/RepoRoot/' . a:relative_path
  call mkdir(fnamemodify(filepath, ':h'), 'p')
  call writefile(a:content, filepath)
endfunction

function! TestGenericOpenCommand()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Weekly': {
        \   'root': 'weekly',
        \   'ext': 'md',
        \   'title_format': '%Y-W%V',
        \ },
        \ })

  call Assert(exists(':WorkflowOpen') == 2, "Command ':WorkflowOpen' should be defined")

  " generic open command accepts file path relative to repo root
  if exists(':WorkflowOpen')
    let relative_path = 'weekly/' . strftime('%Y-W%V') . '.md'
    call s:create_file(relative_path, ['# Weekly Note'])
    execute 'WorkflowOpen ' . relative_path
    call AssertEqual(g:test_workspace . '/RepoRoot/' . relative_path, bufname('%'),
          \ "File opened by ':WorkflowOpen' command is incorrect")
    call delete(g:test_workspace . '/RepoRoot/' . relative_path)
  endif
endfunction

function! TestGenericOpenCommandOutsideRepoRoot()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {
        \   'root': './',
        \   'ext': 'md',
        \ },
        \ })
  " generic open command throws error for file outside repo root
  call AssertThrows('WorkflowOpen ../outside.md',
        \ 'outside root',
        \ "Command ':WorkflowOpen' should throw an error when file is outside repo root")

endfunction

function! TestGenericOpenCommandNonExistentFile()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Weekly': {
        \   'root': 'weekly',
        \   'ext': 'md',
        \   'title_format': '%Y-W%V',
        \ },
        \ })
  " generic open command throws error for non-existent file
  call AssertThrows('WorkflowOpen weekly/nonexistent.md',
        \ 'No such file',
        \ "Command ':WorkflowOpen' should throw an error when file does not exist")
endfunction

" TODO when workflow autocmds are supported, validate that the right
" autocmds run (i.e. workflow resolution works)

function! TestWorkflowSpecificCommand()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {
        \   'root': './',
        \   'ext': 'md',
        \   'title_format': '$title',
        \ },
        \ 'Capture': {
        \   'root': 'capture/',
        \   'ext': 'md',
        \   'title_format': '%Y-%m-%d $title',
        \ },
        \ })

  " Test with a regular workflow...
  call Assert(exists(':CaptureOpen') == 2, "Command ':CaptureOpen' should be defined")
  if exists(':CaptureOpen')
    let relative_path = 'capture/2024-06-15 Meeting.md'
    call s:create_file(relative_path, ['# Capture Meeting'])
    CaptureOpen 2024-06-15 Meeting.md
    call AssertEqual(g:test_workspace . '/RepoRoot/capture/2024-06-15 Meeting.md', bufname('%'),
          \ "File opened by ':CaptureOpen' command is incorrect")
    call delete(relative_path)
  endif

  " ...and with a workflow rooted at repo root
  call Assert(exists(':PageOpen') == 2, "Command ':PageOpen' should be defined")
  if exists(':PageOpen')
    let relative_path = 'My First Page.md'
    call s:create_file(relative_path, ['# My First Page'])
    PageOpen My First Page.md
    call AssertEqual(g:test_workspace . '/RepoRoot/My First Page.md', bufname('%'),
          \ "File opened by ':PageOpen' command is incorrect")
    call delete(relative_path)
  endif
endfunction

function! TestWorkflowOpenCommandCompletion()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \ 'Page': {
        \   'root': './',
        \   'ext': 'md',
        \   'title_format': '$title',
        \ },
        \ 'Capture': {
        \   'root': 'capture/',
        \   'ext': 'md',
        \   'title_format': '%Y-%m-%d $title',
        \ },
        \ })

  " Test with a regular workflow...
  call Assert(exists(':CaptureOpen') == 2, "Command ':CaptureOpen' should be defined")
  if exists(':CaptureOpen')
    let relative_path = 'capture/2024-06-15 Meeting.md'
    call s:create_file(relative_path, ['# Capture Meeting'])
    let completions = StructAutogen_complete_Capture_Open('2024', 'CaptureOpen 2024', 15)
    call AssertEqual([ '2024-06-15 Meeting.md' ], completions,
          \ "Completion function for ':CaptureOpen' command returned incorrect completions")
    call delete(relative_path)
  endif

  " ...and with a workflow rooted at repo root
  call Assert(exists(':PageOpen') == 2, "Command ':PageOpen' should be defined")
  if exists(':PageOpen')
    let relative_path = 'My First Page.md'
    call s:create_file(relative_path, ['# My First Page'])
    let completions = StructAutogen_complete_Page_Open('', 'PageOpen ', 10)
    call AssertEqual([ 'My First Page.md' ], completions,
          \ "Completion function for ':PageOpen' command returned incorrect completions")
    call delete(relative_path)
  endif
endfunction
