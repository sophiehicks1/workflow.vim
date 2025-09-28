" Simple test for debugging the test framework

function! TestFrameworkWorks()
  call Assert(1 == 1, "Basic arithmetic should work")
  call AssertEqual("hello", "hello", "String equality should work")
endfunction

function! TestVariablesExist()  
  call AssertExists("g:test_module_name", "test_module_name should exist")
  call AssertExists("g:test_temp_dir", "test_temp_dir should exist")
endfunction