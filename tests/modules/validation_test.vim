" Validation and error handling tests for workflow.vim
" Tests workflow validation, error handling, and edge cases

" Test mandatory ext key validation
function! TestMandatoryExtValidation()
  " Test workflow missing ext key
  let g:struct_workflows = {
        \ 'InvalidExt': {
        \   'root': g:test_workspace . '/invalid_ext'
        \ }
        \ }
  
  " Should fail validation when struct#initialize() is called
  call AssertThrows('call struct#initialize()', 'mandatory.*ext', 'Should fail due to missing ext key')
endfunction

" Test mandatory root key validation  
function! TestMandatoryRootValidation()
  let g:struct_workflows = {
        \ 'InvalidRoot': {
        \   'ext': 'txt'
        \ }
        \ }
  
  call AssertThrows('call struct#initialize()', 'mandatory.*root', 'Should fail due to missing root key')
endfunction

" Test root directory creation
function! TestRootDirectoryCreation()
  let test_root = g:test_workspace . '/auto_created_root'
  
  " Ensure directory doesn't exist
  call system('rm -rf ' . shellescape(test_root))
  call AssertFileNotExists(test_root, 'Root directory should not exist initially')
  
  call CreateTestWorkflow('AutoRoot', {
        \ 'root': test_root,
        \ 'ext': 'txt',
        \ 'date': 0
        \ })
  
  " Directory should be created automatically
  call AssertDirExists(test_root, 'Root directory should be created automatically')
endfunction

" Test invalid root directory (file exists with same name)
function! TestInvalidRootDirectory()
  let invalid_root = g:test_workspace . '/invalid_root_file'
  
  " Create a file with the same name as the intended root directory
  call CreateTestFile(invalid_root, 'This is a file, not a directory')
  call AssertFileExists(invalid_root, 'File should exist where directory is expected')
  
  let g:struct_workflows = {
        \ 'InvalidRootDir': {
        \   'root': invalid_root,
        \   'ext': 'txt'
        \ }
        \ }
  
  " Should fail because root is a file, not a directory
  call AssertThrows('call struct#initialize()', 'not a directory', 'Should fail when root is a file')
endfunction

" Test workflow with empty name
function! TestEmptyWorkflowName()
  let g:struct_workflows = {
        \ '': {
        \   'root': g:test_workspace . '/empty_name',
        \   'ext': 'txt',
        \   'date': 0
        \ }
        \ }
  
  call AssertThrows('call struct#initialize()', 'name.*empty', 'Should fail due to empty workflow name')
endfunction

" Test workflow with special characters in name
function! TestSpecialCharacterWorkflowName()
  let g:struct_workflows = {
        \ 'Test-Workflow_123': {
        \   'root': g:test_workspace . '/special_chars',
        \   'ext': 'txt',
        \   'date': 0
        \ }
        \ }
  
  call AssertThrows('call struct#initialize()', 'name.*alphanumeric', 'Should fail due to non alphanumeric characters')
endfunction

" Test workflow extension validation
function! TestWorkflowExtensions()
  " Test various file extensions
  let extensions = ['txt', 'md', 'html', 'py', 'vim', 'js', 'css', 'json', 'xml', 'yml']
  
  for ext in extensions
    let workflow_name = 'Test' . toupper(ext)
    call CreateTestWorkflow(workflow_name, {
          \ 'root': g:test_workspace . '/' . ext . '_files',
          \ 'ext': ext,
          \ 'date': 0
          \ })
    
    call AssertEqual(ext, g:struct_workflows[workflow_name]['ext'], 'Extension should be set correctly for ' . ext)
  endfor
endfunction

" Test numeric and boolean workflow options
function! TestWorkflowOptionTypes()
  call CreateTestWorkflow('TypeTest', {
        \ 'root': g:test_workspace . '/type_test',
        \ 'ext': 'txt',
        \ 'date': 1,
        \ 'mandatory-title': 1,
        \ 'nested': 0,
        \ 'period': 'weekly'
        \ })
  
  let workflow = g:struct_workflows['TypeTest']
  
  " Test numeric values
  call AssertEqual(1, workflow['date'], 'Date should be numeric 1')
  call AssertEqual(1, workflow['mandatory-title'], 'Mandatory title should be numeric 1')
  call AssertEqual(0, workflow['nested'], 'Nested should be numeric 0')
  
  " Test string values
  call AssertEqual('weekly', workflow['period'], 'Period should be string "weekly"')
endfunction

" Test workflow path resolution
function! TestWorkflowPathResolution()
  " Test absolute path
  let abs_path = g:test_workspace . '/absolute_path'
  call CreateTestWorkflow('AbsolutePath', {
        \ 'root': abs_path,
        \ 'ext': 'txt',
        \ 'date': 0
        \ })
  
  call AssertMatches(abs_path, g:struct_workflows['AbsolutePath']['root'], 'Absolute path should be preserved')
  
  " Test relative path (relative to current working directory)
  call CreateTestWorkflow('RelativePath', {
        \ 'root': 'test',
        \ 'ext': 'txt',
        \ 'date': 0
        \ })
  
  call AssertEqual('test', g:struct_workflows['RelativePath']['root'], 'Relative path should be preserved')
endfunction

" Test overwriting existing workflow
function! TestOverwriteExistingWorkflow()
  " Create initial workflow
  call CreateTestWorkflow('Overwrite', {
        \ 'root': g:test_workspace . '/original',
        \ 'ext': 'txt',
        \ 'date': 0
        \ })
  
  call AssertEqual('txt', g:struct_workflows['Overwrite']['ext'], 'Original extension should be txt')
  
  " Overwrite with new configuration
  call CreateTestWorkflow('Overwrite', {
        \ 'root': g:test_workspace . '/updated',
        \ 'ext': 'md',
        \ 'date': 1
        \ })
  
  call AssertEqual('md', g:struct_workflows['Overwrite']['ext'], 'Extension should be updated to md')
  call AssertEqual(1, g:struct_workflows['Overwrite']['date'], 'Date should be updated to 1')
endfunction

" Test large number of workflows
function! TestManyWorkflows()
  let workflow_count = 10
  
  for i in range(workflow_count)
    let workflow_name = 'MassTest' . i
    call CreateTestWorkflow(workflow_name, {
          \ 'root': g:test_workspace . '/mass_test_' . i,
          \ 'ext': 'txt',
          \ 'date': (i % 2)
          \ })
  endfor
  
  " Verify all workflows were created
  call AssertEqual(workflow_count, len(keys(g:struct_workflows)), 'Should have created ' . workflow_count . ' workflows')
  
  " Verify each workflow has correct properties
  for i in range(workflow_count)
    let workflow_name = 'MassTest' . i
    call Assert(has_key(g:struct_workflows, workflow_name), 'Workflow ' . workflow_name . ' should exist')
    call AssertEqual(i % 2, g:struct_workflows[workflow_name]['date'], 'Date setting should be correct for ' . workflow_name)
  endfor
endfunction

" Test workflow with missing optional keys
function! TestMissingOptionalKeys()
  " Create minimal workflow with only required keys
  call CreateTestWorkflow('Minimal', {
        \ 'root': g:test_workspace . '/minimal',
        \ 'ext': 'txt'
        \ })
  
  let workflow = g:struct_workflows['Minimal']
  call AssertEqual('txt', workflow['ext'], 'Extension should be set')
  call Assert(!has_key(workflow, 'date') || workflow['date'] == 0, 'Date should be missing or 0')
  call Assert(!has_key(workflow, 'template'), 'Template should be missing')
  call Assert(!has_key(workflow, 'period'), 'Period should be missing')
  call Assert(!has_key(workflow, 'onload'), 'Onload should be missing')
  call Assert(!has_key(workflow, 'oncreate'), 'Oncreate should be missing')
endfunction

" Test very long workflow names and paths
function! TestLongNamesAndPaths()
  let long_name = 'VeryLongWorkflowNameThatExceedsNormalLengthExpectations'
  let long_path = g:test_workspace . '/very/deeply/nested/directory/structure/for/testing/long/paths'
  
  call CreateTestWorkflow(long_name, {
        \ 'root': long_path,
        \ 'ext': 'txt',
        \ 'date': 0
        \ })
  
  call Assert(has_key(g:struct_workflows, long_name), 'Long workflow name should work')
  call AssertDirExists(long_path, 'Long path should be created')
endfunction
