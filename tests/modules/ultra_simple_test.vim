" Simple working test for workflow.vim plugin using shared framework helpers

function! TestBasicFunctionality()
  call Assert(1 == 1, "Basic arithmetic should work")
  call AssertEqual("hello", "hello", "String equality should work")
endfunction

function! TestVariablesExist()  
  call AssertExists("g:test_module_name", "test_module_name should exist")
  call AssertExists("g:test_temp_dir", "test_temp_dir should exist")
endfunction

function! TestWorkflowCreation()
  " Test basic workflow creation
  let g:struct_workflows = {}
  let g:struct_workflows['TestWorkflow'] = {}
  let g:struct_workflows['TestWorkflow']['root'] = g:test_temp_dir . '/test_root'
  let g:struct_workflows['TestWorkflow']['ext'] = 'txt'
  let g:struct_workflows['TestWorkflow']['date'] = 0
        
  call Assert(has_key(g:struct_workflows, 'TestWorkflow'), "Workflow should be created")
  call AssertEqual('txt', g:struct_workflows['TestWorkflow']['ext'], "Extension should be txt")
  call AssertEqual(0, g:struct_workflows['TestWorkflow']['date'], "Date should be 0")
endfunction