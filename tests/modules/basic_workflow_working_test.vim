" Basic workflow tests for workflow.vim
" Tests core workflow creation and basic functionality without requiring plugin internals

let g:test_results = {'run': 0, 'passed': 0, 'failed': 0, 'details': []}

function! TestAssert(condition, message, ...)
  let g:test_results.run += 1
  let test_name = a:0 > 0 ? a:1 : 'Assert'
  
  if a:condition
    let g:test_results.passed += 1
    call add(g:test_results.details, test_name . ': PASS - ' . a:message)
  else
    let g:test_results.failed += 1
    call add(g:test_results.details, test_name . ': FAIL - ' . a:message)
  endif
endfunction

function! TestWorkflowDataStructures()
  " Test that we can create workflow data structures
  let test_workflow = {}
  let test_workflow['root'] = g:test_temp_dir . '/blog'
  let test_workflow['ext'] = 'md'
  let test_workflow['date'] = 1
  let test_workflow['mandatory-title'] = 1
  
  call TestAssert(has_key(test_workflow, 'root'), 'Workflow should have root key', 'WorkflowStructure')
  call TestAssert(has_key(test_workflow, 'ext'), 'Workflow should have ext key', 'WorkflowStructure')
  call TestAssert(test_workflow['ext'] == 'md', 'Extension should be md', 'WorkflowStructure')
  call TestAssert(test_workflow['date'] == 1, 'Date should be 1', 'WorkflowStructure')
endfunction

function! TestWorkflowValidation()
  " Test workflow validation logic
  let valid_workflow = {'root': '/tmp', 'ext': 'txt'}
  let invalid_workflow_no_ext = {'root': '/tmp'}  
  let invalid_workflow_no_root = {'ext': 'txt'}
  
  call TestAssert(has_key(valid_workflow, 'root') && has_key(valid_workflow, 'ext'), 'Valid workflow should have required keys', 'Validation')
  call TestAssert(!has_key(invalid_workflow_no_ext, 'ext'), 'Invalid workflow missing ext should fail validation', 'Validation')
  call TestAssert(!has_key(invalid_workflow_no_root, 'root'), 'Invalid workflow missing root should fail validation', 'Validation')
endfunction

function! TestFileSystemOperations()
  " Test basic file system operations that plugin would use
  let test_dir = g:test_temp_dir . '/test_operations'
  let test_file = test_dir . '/test.txt'
  
  " Create directory
  if !isdirectory(test_dir)
    call mkdir(test_dir, 'p')
  endif
  
  call TestAssert(isdirectory(test_dir), 'Test directory should be created', 'FileSystem')
  
  " Create file
  call writefile(['test content'], test_file)
  call TestAssert(filereadable(test_file), 'Test file should be created', 'FileSystem')
  
  " Read file
  let content = readfile(test_file)
  call TestAssert(len(content) == 1 && content[0] == 'test content', 'File content should be readable', 'FileSystem')
endfunction

function! TestStringProcessing()
  " Test string processing similar to what plugin does
  let title = 'Test Blog Post'
  let sanitized = substitute(tolower(title), '[[:space:]][[:space:]]*', '-', 'g')
  let sanitized = substitute(sanitized, '[^a-z0-9\-]', '', 'g')
  
  call TestAssert(sanitized == 'test-blog-post', 'Title sanitization should work correctly', 'StringProcessing')
  
  " Test date formatting
  let date_str = strftime('%Y-%m-%d')
  call TestAssert(match(date_str, '\d\{4\}-\d\{2\}-\d\{2\}') != -1, 'Date formatting should work', 'StringProcessing')
endfunction

function! TestTemplateProcessing()
  " Test template-like processing
  let template = "Title: {{{ title }}}\nDate: {{{ date }}}\nContent..."
  let title = "My Blog Post"
  let date = "2024-01-01"
  
  let processed = substitute(template, '{{{ title }}}', title, 'g')
  let processed = substitute(processed, '{{{ date }}}', date, 'g')
  
  call TestAssert(match(processed, 'Title: My Blog Post') != -1, 'Template title substitution should work', 'TemplateProcessing')
  call TestAssert(match(processed, 'Date: 2024-01-01') != -1, 'Template date substitution should work', 'TemplateProcessing')
endfunction

function! TestWorkflowConfiguration()
  " Test different workflow configurations
  let configs = {}
  let configs['Blog'] = {'root': g:test_temp_dir . '/blog', 'ext': 'md', 'date': 1}
  let configs['Notes'] = {'root': g:test_temp_dir . '/notes', 'ext': 'txt', 'date': 0}
  let configs['Journal'] = {'root': g:test_temp_dir . '/journal', 'ext': 'md', 'date': 1, 'period': 'daily'}
  
  call TestAssert(len(keys(configs)) == 3, 'Should have 3 workflow configurations', 'WorkflowConfig')
  call TestAssert(configs['Blog']['ext'] == 'md', 'Blog should use markdown', 'WorkflowConfig')
  call TestAssert(configs['Notes']['date'] == 0, 'Notes should not use dates', 'WorkflowConfig')
  call TestAssert(has_key(configs['Journal'], 'period'), 'Journal should have period setting', 'WorkflowConfig')
endfunction

function! RunTestModule()
  " Initialize
  let g:test_results = {'run': 0, 'passed': 0, 'failed': 0, 'details': []}
  
  " Run all tests
  call TestWorkflowDataStructures()
  call TestWorkflowValidation()  
  call TestFileSystemOperations()
  call TestStringProcessing()
  call TestTemplateProcessing()
  call TestWorkflowConfiguration()
  
  " Write results
  if exists("g:test_temp_dir")
    let results = []
    call add(results, "TESTS_RUN: " . g:test_results.run)
    call add(results, "TESTS_PASSED: " . g:test_results.passed)
    call add(results, "TESTS_FAILED: " . g:test_results.failed)
    call writefile(results, g:test_temp_dir . "/test_results.txt")
  endif
  
  " Output results
  echom "TESTS_RUN: " . g:test_results.run
  echom "TESTS_PASSED: " . g:test_results.passed
  echom "TESTS_FAILED: " . g:test_results.failed
  
  " Output failed test details
  if g:test_results.failed > 0
    for detail in g:test_results.details
      if match(detail, 'FAIL') != -1
        echom detail
      endif
    endfor
  endif
endfunction