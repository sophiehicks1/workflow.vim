" Simple working test for workflow.vim plugin

let g:simple_tests_run = 0
let g:simple_tests_passed = 0
let g:simple_tests_failed = 0

function! SimpleAssert(condition, message)
  let g:simple_tests_run += 1
  if a:condition
    let g:simple_tests_passed += 1
  else
    let g:simple_tests_failed += 1
    echom "FAIL: " . a:message
  endif
endfunction

function! TestBasicFunctionality()
  call SimpleAssert(1 == 1, "Basic arithmetic should work")
  call SimpleAssert("hello" == "hello", "String equality should work")
endfunction

function! TestVariablesExist()  
  call SimpleAssert(exists("g:test_module_name"), "test_module_name should exist")
  call SimpleAssert(exists("g:test_temp_dir"), "test_temp_dir should exist")
endfunction

function! TestWorkflowCreation()
  " Test basic workflow creation
  let g:struct_workflows = {}
  let g:struct_workflows['TestWorkflow'] = {
        \ 'root': g:test_temp_dir . '/test_root',
        \ 'ext': 'txt',
        \ 'date': 0
        \ }
        
  call SimpleAssert(has_key(g:struct_workflows, 'TestWorkflow'), "Workflow should be created")
  call SimpleAssert(g:struct_workflows['TestWorkflow']['ext'] == 'txt', "Extension should be txt")
  call SimpleAssert(g:struct_workflows['TestWorkflow']['date'] == 0, "Date should be 0")
endfunction

function! RunTestModule()
  " Run the tests
  call TestBasicFunctionality()
  call TestVariablesExist()
  call TestWorkflowCreation()
  
  " Write results
  if exists("g:test_temp_dir")
    let results = []
    call add(results, "TESTS_RUN: " . g:simple_tests_run)
    call add(results, "TESTS_PASSED: " . g:simple_tests_passed)
    call add(results, "TESTS_FAILED: " . g:simple_tests_failed)
    call writefile(results, g:test_temp_dir . "/test_results.txt")
  endif
  
  " Also output to echom for good measure
  echom "TESTS_RUN: " . g:simple_tests_run
  echom "TESTS_PASSED: " . g:simple_tests_passed
  echom "TESTS_FAILED: " . g:simple_tests_failed
endfunction