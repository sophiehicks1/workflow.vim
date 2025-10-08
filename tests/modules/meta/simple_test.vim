" Simple test for debugging the test framework

function! TestFrameworkWorks()
  call Assert(1 == 1, "Basic arithmetic should work")
  call AssertEqual("hello", "hello", "String equality should work")
endfunction

function! TestVariablesExist()  
  call AssertExists("g:test_module_name", "test_module_name should exist")
  call AssertExists("g:test_temp_dir", "test_temp_dir should exist")
endfunction

function! TestFileSystemSetup()
  " Check that the test workspace directory exists
  call Assert(isdirectory(g:test_workspace), "Test workspace should be a directory")
  
  " Check that the test workspace contains the expected initial files
  let l:setup_files = split(glob("./tests/data/**/*"), '\n')
  for file in l:setup_files
    let relative_path = substitute(file, './tests/data/', '', '')
    let test_path = g:test_workspace . '/' . relative_path
    call Assert(filereadable(test_path) || isdirectory(test_path),
          \ "Expected file or directory '" . test_path . "' to exist")
  endfor
endfunction
