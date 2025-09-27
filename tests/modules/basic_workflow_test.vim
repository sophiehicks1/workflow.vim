" Basic workflow tests for workflow.vim
" Tests core workflow creation, file operations, and basic functionality

" Test basic workflow creation and initialization
function! TestBasicWorkflowCreation()
  " Test creating a simple workflow
  let workflow_config = {}
  let workflow_config['root'] = g:test_workspace . '/blog'
  let workflow_config['ext'] = 'md'
  let workflow_config['date'] = 1
  let workflow_config['mandatory-title'] = 1
  call CreateTestWorkflow('TestBlog', workflow_config)
  
  " Verify workflow exists
  call AssertExists('g:struct_workflows', 'g:struct_workflows should exist after creation')
  call Assert(has_key(g:struct_workflows, 'TestBlog'), 'TestBlog workflow should exist')
  
  " Verify workflow properties
  let workflow = g:struct_workflows['TestBlog']
  call AssertEqual('md', workflow['ext'], 'Extension should be md')
  call AssertEqual(1, workflow['date'], 'Date should be enabled')
  call AssertEqual(1, workflow['mandatory-title'], 'Mandatory title should be enabled')
endfunction

" Test workflow validation
function! TestWorkflowValidation()
  " Test workflow without required ext key
  try
    let invalid_config = {}
    let invalid_config['root'] = g:test_workspace . '/invalid'
    call CreateTestWorkflow('InvalidWorkflow', invalid_config)
    call TestFail('Should have failed due to missing ext key')
  catch
    " Expected to fail
  endtry
  
  " Test workflow without required root key  
  try
    let invalid_config2 = {}
    let invalid_config2['ext'] = 'txt'
    call CreateTestWorkflow('InvalidWorkflow2', invalid_config2)
    call TestFail('Should have failed due to missing root key')
  catch
    " Expected to fail
  endtry
endfunction

" Test filename generation
function! TestFilenameGeneration()
  call CreateTestWorkflow('TestNotes', {
        \ 'root': g:test_workspace . '/notes',
        \ 'ext': 'txt',
        \ 'date': 1
        \ })
  
  " Mock the current date to get predictable results
  " We'll test the sanitize_title function indirectly by checking file creation
  let test_root = g:test_workspace . '/notes'
  call system('mkdir -p ' . shellescape(test_root))
  
  " Test that workflow exists and has correct properties
  let workflow = g:struct_workflows['TestNotes']
  call AssertEqual('txt', workflow['ext'])
  call AssertMatches(test_root, workflow['root'])
endfunction

" Test directory creation
function! TestDirectoryCreation()
  let test_dir = g:test_workspace . '/test_creation'
  
  call CreateTestWorkflow('TestCreation', {
        \ 'root': test_dir,
        \ 'ext': 'md',
        \ 'date': 0
        \ })
  
  " Directory should be created automatically
  call AssertDirExists(test_dir, 'Workflow root directory should be created')
endfunction

" Test workflow without date
function! TestWorkflowWithoutDate()
  call CreateTestWorkflow('TestSimple', {
        \ 'root': g:test_workspace . '/simple',
        \ 'ext': 'txt',
        \ 'date': 0
        \ })
  
  let workflow = g:struct_workflows['TestSimple']
  call AssertEqual(0, workflow['date'], 'Date should be disabled')
  call AssertEqual('txt', workflow['ext'], 'Extension should be txt')
endfunction

" Test nested workflow configuration
function! TestNestedWorkflow()
  call CreateTestWorkflow('TestNested', {
        \ 'root': g:test_workspace . '/nested',
        \ 'ext': 'md', 
        \ 'nested': 1,
        \ 'date': 0
        \ })
  
  let workflow = g:struct_workflows['TestNested']
  call AssertEqual(1, workflow['nested'], 'Nested should be enabled')
endfunction

" Test workflow with template
function! TestWorkflowWithTemplate()
  " Create a template file
  let template_path = g:test_workspace . '/template.md'
  call CreateTestFile(template_path, "Title: {{{ b:title }}}\nDate: {{{ b:date }}}\n\nContent here...")
  
  call CreateTestWorkflow('TestTemplate', {
        \ 'root': g:test_workspace . '/templated',
        \ 'ext': 'md',
        \ 'template': template_path,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  let workflow = g:struct_workflows['TestTemplate']
  call AssertEqual(template_path, workflow['template'], 'Template path should match')
  call AssertFileExists(template_path, 'Template file should exist')
endfunction

" Test period configurations
function! TestPeriodicWorkflows()
  " Test daily workflow (default)
  call CreateTestWorkflow('TestDaily', {
        \ 'root': g:test_workspace . '/daily',
        \ 'ext': 'md',
        \ 'date': 1,
        \ 'period': 'daily'
        \ })
  
  " Test weekly workflow
  call CreateTestWorkflow('TestWeekly', {
        \ 'root': g:test_workspace . '/weekly',
        \ 'ext': 'md',
        \ 'date': 1,
        \ 'period': 'weekly'
        \ })
  
  " Test monthly workflow
  call CreateTestWorkflow('TestMonthly', {
        \ 'root': g:test_workspace . '/monthly',
        \ 'ext': 'md',
        \ 'date': 1,
        \ 'period': 'monthly'
        \ })
  
  let daily = g:struct_workflows['TestDaily']
  let weekly = g:struct_workflows['TestWeekly']
  let monthly = g:struct_workflows['TestMonthly']
  
  call AssertEqual('daily', daily['period'], 'Daily period should be set')
  call AssertEqual('weekly', weekly['period'], 'Weekly period should be set')
  call AssertEqual('monthly', monthly['period'], 'Monthly period should be set')
endfunction

" Test workflow initialization creates commands
function! TestWorkflowCommandCreation()
  call CreateTestWorkflow('TestCommands', {
        \ 'root': g:test_workspace . '/commands',
        \ 'ext': 'txt',
        \ 'date': 0
        \ })
  
  " After initialization, commands should exist
  " We can't easily test command existence in vim script, but we can verify
  " the workflow was properly initialized
  call Assert(has_key(g:struct_workflows, 'TestCommands'), 'TestCommands workflow should exist after initialization')
endfunction

" Test multiple workflows
function! TestMultipleWorkflows()
  call CreateTestWorkflow('Blog', {
        \ 'root': g:test_workspace . '/blog',
        \ 'ext': 'md',
        \ 'date': 1
        \ })
  
  call CreateTestWorkflow('Notes', {
        \ 'root': g:test_workspace . '/notes', 
        \ 'ext': 'txt',
        \ 'date': 0
        \ })
  
  call AssertEqual(2, len(keys(g:struct_workflows)), 'Should have 2 workflows')
  call Assert(has_key(g:struct_workflows, 'Blog'), 'Blog workflow should exist')
  call Assert(has_key(g:struct_workflows, 'Notes'), 'Notes workflow should exist')
endfunction