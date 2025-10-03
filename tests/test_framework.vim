" Test framework for workflow.vim
" Provides assertion functions, test setup/teardown, and test execution

" Global test state variables
let g:test_results = {}
let g:current_test_name = ""
let g:tests_run = 0
let g:tests_passed = 0
let g:tests_failed = 0

" Test framework initialization
function! TestFrameworkInit()
  let g:test_results = {}
  let g:current_test_name = ""
  let g:tests_run = 0
  let g:tests_passed = 0
  let g:tests_failed = 0
  
  " Create unique test workspace using vim's built-in functions
  if exists("g:test_temp_dir")
    let g:test_workspace = g:test_temp_dir . "/" . g:test_module_name . "_workspace"
    if !isdirectory(g:test_workspace)
      call mkdir(g:test_workspace, 'p')
    endif
  else
    let g:test_workspace = "/tmp/workflow_vim_test_" . localtime()
    if !isdirectory(g:test_workspace)
      call mkdir(g:test_workspace, 'p')
    endif
  endif
endfunction

" Test framework cleanup
function! TestFrameworkCleanup()
  " Clean up test workspace if it exists
  if exists("g:test_workspace") && isdirectory(g:test_workspace)
    call system("rm -rf " . shellescape(g:test_workspace))
  endif
endfunction

" Assert that a condition is true
function! Assert(condition, message)
  if !a:condition
    call TestFail("Assertion failed: " . a:message)
  endif
endfunction

" Assert that two values are equal
function! AssertEqual(expected, actual, ...)
  let message = a:0 > 0 ? a:1 : "Expected " . string(a:expected) . " but got " . string(a:actual)
  if a:expected != a:actual
    call TestFail("AssertEqual failed: " . message)
  endif
endfunction

" Assert that two values are not equal
function! AssertNotEqual(expected, actual, ...)
  let message = a:0 > 0 ? a:1 : "Expected not " . string(a:expected) . " but got " . string(a:actual)
  if a:expected == a:actual
    call TestFail("AssertNotEqual failed: " . message)
  endif
endfunction

" Assert that a string matches a pattern
function! AssertMatches(pattern, actual, ...)
  let message = a:0 > 0 ? a:1 : "Expected pattern " . string(a:pattern) . " but got " . string(a:actual)
  if match(a:actual, a:pattern) == -1
    call TestFail("AssertMatches failed: " . message)
  endif
endfunction

" Assert that a file exists
function! AssertFileExists(filepath, ...)
  let message = a:0 > 0 ? a:1 : "Expected file " . a:filepath . " to exist"
  if !filereadable(a:filepath)
    call TestFail("AssertFileExists failed: " . message)
  endif
endfunction

" Assert that a file does not exist
function! AssertFileNotExists(filepath, ...)
  let message = a:0 > 0 ? a:1 : "Expected file " . a:filepath . " to not exist"
  if filereadable(a:filepath)
    call TestFail("AssertFileNotExists failed: " . message)
  endif
endfunction

" Assert that a directory exists
function! AssertDirExists(dirpath, ...)
  let message = a:0 > 0 ? a:1 : "Expected directory " . a:dirpath . " to exist"
  if !isdirectory(a:dirpath)
    call TestFail("AssertDirExists failed: " . message)
  endif
endfunction

" Assert that a variable exists
function! AssertExists(varname, ...)
  let message = a:0 > 0 ? a:1 : "Expected variable " . a:varname . " to exist"
  if !exists(a:varname)
    call TestFail("AssertExists failed: " . message)
  endif
endfunction

" Assert that an exception is thrown
function! AssertThrows(command, pattern, ...)
  let message = a:0 > 0 ? a:1 : "Expected exception matching " . string(a:pattern) . " from command: " . a:command
  let caught = 0
  try
    execute a:command
  catch
    echo "Caught exception: " . v:exception
    if match(v:exception, a:pattern) != -1
      let caught = 1
    else
      call TestFail("AssertThrows failed: Wrong exception thrown. Expected pattern " . string(a:pattern) . " but got: " . v:exception)
    endif
  endtry
  
  if !caught
    call TestFail("AssertThrows failed: " . message)
  endif
endfunction

" Record a test failure with detailed information
function! TestFail(message)
  let error_info = {}
  let error_info['test'] = g:current_test_name
  let error_info['message'] = a:message
  let error_info['file'] = expand('%:p')
  let error_info['line'] = line('.')
  let error_info['time'] = strftime('%Y-%m-%d %H:%M:%S')
  
  if !has_key(g:test_results, g:current_test_name)
    let g:test_results[g:current_test_name] = {'status': 'unknown', 'errors': []}
  endif
  
  let g:test_results[g:current_test_name].status = 'failed'
  call add(g:test_results[g:current_test_name].errors, error_info)
  
  " Throw exception to stop test execution
  throw "TEST_FAILURE: " . a:message
endfunction

" Set up before each test
function! TestSetup()
  " Clear any existing workflows
  if exists("g:struct_workflows")
    unlet g:struct_workflows
  endif
  
  " Create fresh test directory for this test
  if exists("g:test_workspace")
    let test_dir = g:test_workspace . "/" . g:current_test_name
    if !isdirectory(test_dir)
      call mkdir(test_dir, 'p')
    endif
    let g:current_test_dir = test_dir
  endif
endfunction

" Clean up after each test
function! TestTeardown()
  " Clear workflows
  if exists("g:struct_workflows")
    unlet g:struct_workflows
  endif
  
  " Clear test-specific variables
  if exists("g:current_test_dir")
    unlet g:current_test_dir
  endif
endfunction

" Run a single test function
function! RunTestFunction(test_name)
  let g:current_test_name = a:test_name
  let g:tests_run += 1
  
  " Initialize test result
  let g:test_results[a:test_name] = {'status': 'unknown', 'errors': []}
  
  " Skip test if function filter is specified and doesn't match
  if exists("g:test_function_filter") && g:test_function_filter != "" && match(a:test_name, g:test_function_filter) == -1
    let g:test_results[a:test_name].status = 'skipped'
    echom "SKIPPING: " . a:test_name . " (filtered out)"
    return
  endif
  
  try
    " Setup
    call TestSetup()
    
    " Run the test
    execute "call " . a:test_name . "()"
    
    " If we get here, the test passed
    let g:test_results[a:test_name].status = 'passed'
    let g:tests_passed += 1
    echom "PASSED: " . a:test_name
    
  catch /^TEST_FAILURE:.*/
    " Test failed with assertion
    let g:tests_failed += 1
    echom "FAILED: " . a:test_name
    for error in g:test_results[a:test_name].errors
      echom "  ERROR: " . error.message
    endfor
    
  catch
    " Test failed with unexpected error
    let g:test_results[a:test_name].status = 'error'
    let g:tests_failed += 1
    let error_info = {}
    let error_info['test'] = a:test_name
    let error_info['message'] = 'Unexpected error: ' . v:exception
    let error_info['file'] = expand('%:p')
    let error_info['line'] = line('.')
    let error_info['time'] = strftime('%Y-%m-%d %H:%M:%S')
    call add(g:test_results[a:test_name].errors, error_info)
    echom "ERROR: " . a:test_name . " - " . v:exception
    
  finally
    " Always clean up
    call TestTeardown()
  endtry
endfunction

" Discover and run all test functions in current file
function! RunTestModule()
  call TestFrameworkInit()
  
  " Get all function names by looking at the test module file
  let functions = []
  " Use g:test_module_file if available (supports subdirectories), 
  " otherwise fallback to old behavior for backwards compatibility
  if exists("g:test_module_file")
    let module_file = g:test_module_file
  else
    let module_file = "tests/modules/" . g:test_module_name . ".vim"
  endif
  
  " Read the test module file to find test functions
  if filereadable(module_file)
    let lines = readfile(module_file)
    for line in lines
      if match(line, '^\s*function!\?\s\+Test\w*\s*(') != -1
        let func_match = matchlist(line, '^\s*function!\?\s\+\(Test\w*\)\s*(')
        if len(func_match) > 1
          call add(functions, func_match[1])
        endif
      endif
    endfor
  else
    echom "ERROR: Cannot read test module file: " . module_file
  endif
  
  " Debug: Print function discovery info
  echom "Module: " . g:test_module_name
  echom "File: " . module_file  
  echom "Found " . len(functions) . " test functions: " . join(functions, ', ')
  
  " Run each test function
  for func_name in functions
    call RunTestFunction(func_name)
  endfor
  
  " Print summary
  echom ""
  echom "TESTS_RUN: " . g:tests_run
  echom "TESTS_PASSED: " . g:tests_passed  
  echom "TESTS_FAILED: " . g:tests_failed
  
  " Also write results to file for the test runner to parse
  if exists("g:test_temp_dir")
    let result_file = g:test_temp_dir . "/test_results.txt"
    let results = []
    call add(results, "TESTS_RUN: " . g:tests_run)
    call add(results, "TESTS_PASSED: " . g:tests_passed)
    call add(results, "TESTS_FAILED: " . g:tests_failed)
    call add(results, "MODULE: " . g:test_module_name)
    call writefile(results, result_file)
    
    " Write detailed failure information to separate file
    if g:tests_failed > 0
      let failure_file = g:test_temp_dir . "/test_failures.txt"
      let failure_details = []
      call add(failure_details, "DETAILED FAILURE REPORT FOR " . g:test_module_name)
      call add(failure_details, "=" . repeat("=", len(g:test_module_name) + 30))
      for test_name in keys(g:test_results)
        let result = g:test_results[test_name]
        if result.status == 'failed' || result.status == 'error'
          call add(failure_details, "")
          call add(failure_details, "FAILED TEST: " . test_name)
          for error in result.errors
            call add(failure_details, "  Message: " . error.message)
            if error.file != ""
              call add(failure_details, "  File: " . error.file . " (line " . error.line . ")")
            endif
            call add(failure_details, "  Time: " . error.time)
          endfor
        endif
      endfor
      call writefile(failure_details, failure_file)
    endif
    
    echom "Results written to: " . result_file
  endif
  
  " Print detailed failure information
  if g:tests_failed > 0
    echom ""
    echom "DETAILED FAILURE REPORT:"
    echom "========================"
    for test_name in keys(g:test_results)
      let result = g:test_results[test_name]
      if result.status == 'failed' || result.status == 'error'
        echom "FAILED TEST: " . test_name
        for error in result.errors
          echom "  Message: " . error.message
          echom "  File: " . error.file . " (line " . error.line . ")"
          echom "  Time: " . error.time
          echom ""
        endfor
      endif
    endfor
  endif
  
  " Note: Cleanup is skipped to avoid system() calls in -e -s mode
endfunction

" Helper function to create a test workflow configuration
function! CreateTestWorkflow(name, config)
  if !exists("g:struct_workflows")
    let g:struct_workflows = {}
  endif
  let g:struct_workflows[a:name] = a:config
  call struct#initialize()
endfunction

" Helper function to create a temporary file with content
function! CreateTestFile(filepath, content)
  let dir = fnamemodify(a:filepath, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  call writefile(split(a:content, '\n'), a:filepath)
endfunction

" Helper function to read file content as string
function! ReadTestFile(filepath)
  if filereadable(a:filepath)
    return join(readfile(a:filepath), "\n")
  else
    return ""
  endif
endfunction
