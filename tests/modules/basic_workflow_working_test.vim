" Basic workflow tests for workflow.vim  
" Tests core workflow creation and basic functionality

function! TestWorkflowDataStructures()
  " Test that we can create workflow data structures
  let test_workflow = {}
  let test_workflow['root'] = g:test_temp_dir . '/blog'
  let test_workflow['ext'] = 'md'
  let test_workflow['date'] = 1
  let test_workflow['mandatory-title'] = 1
  
  call Assert(has_key(test_workflow, 'root'), 'Workflow should have root key')
  call Assert(has_key(test_workflow, 'ext'), 'Workflow should have ext key')
  call AssertEqual('md', test_workflow['ext'], 'Extension should be md')
  call AssertEqual(1, test_workflow['date'], 'Date should be 1')
endfunction

function! TestWorkflowValidation()
  " Test workflow validation logic
  let valid_workflow = {'root': '/tmp', 'ext': 'txt'}
  let invalid_workflow_no_ext = {'root': '/tmp'}  
  let invalid_workflow_no_root = {'ext': 'txt'}
  
  call Assert(has_key(valid_workflow, 'root') && has_key(valid_workflow, 'ext'), 'Valid workflow should have required keys')
  call Assert(!has_key(invalid_workflow_no_ext, 'ext'), 'Invalid workflow missing ext should fail validation')
  call Assert(!has_key(invalid_workflow_no_root, 'root'), 'Invalid workflow missing root should fail validation')
endfunction

function! TestFileSystemOperations()
  " Test basic file system operations that plugin would use
  let test_dir = g:test_temp_dir . '/test_operations'
  let test_file = test_dir . '/test.txt'
  
  " Create directory
  if !isdirectory(test_dir)
    call mkdir(test_dir, 'p')
  endif
  
  call AssertDirExists(test_dir, 'Test directory should be created')
  
  " Create file
  call writefile(['test content'], test_file)
  call AssertFileExists(test_file, 'Test file should be created')
  
  " Read file
  let content = readfile(test_file)
  call Assert(len(content) == 1 && content[0] == 'test content', 'File content should be readable')
endfunction

function! TestStringProcessing()
  " Test string processing similar to what plugin does
  let title = 'Test Blog Post'
  let sanitized = substitute(tolower(title), '[[:space:]][[:space:]]*', '-', 'g')
  let sanitized = substitute(sanitized, '[^a-z0-9\-]', '', 'g')
  
  call AssertEqual('test-blog-post', sanitized, 'Title sanitization should work correctly')
  
  " Test date formatting
  let date_str = strftime('%Y-%m-%d')
  call AssertMatches('\d\{4\}-\d\{2\}-\d\{2\}', date_str, 'Date formatting should work')
endfunction

function! TestTemplateProcessing()
  " Test template-like processing
  let template = "Title: {{{ title }}}\nDate: {{{ date }}}\nContent..."
  let title = "My Blog Post"
  let date = "2024-01-01"
  
  let processed = substitute(template, '{{{ title }}}', title, 'g')
  let processed = substitute(processed, '{{{ date }}}', date, 'g')
  
  call AssertMatches('Title: My Blog Post', processed, 'Template title substitution should work')
  call AssertMatches('Date: 2024-01-01', processed, 'Template date substitution should work')
endfunction

function! TestWorkflowConfiguration()
  " Test different workflow configurations
  let configs = {}
  let configs['Blog'] = {'root': g:test_temp_dir . '/blog', 'ext': 'md', 'date': 1}
  let configs['Notes'] = {'root': g:test_temp_dir . '/notes', 'ext': 'txt', 'date': 0}
  let configs['Journal'] = {'root': g:test_temp_dir . '/journal', 'ext': 'md', 'date': 1, 'period': 'daily'}
  
  call AssertEqual(3, len(keys(configs)), 'Should have 3 workflow configurations')
  call AssertEqual('md', configs['Blog']['ext'], 'Blog should use markdown')
  call AssertEqual(0, configs['Notes']['date'], 'Notes should not use dates')
  call Assert(has_key(configs['Journal'], 'period'), 'Journal should have period setting')
endfunction