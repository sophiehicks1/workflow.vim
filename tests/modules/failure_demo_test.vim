" Test module that demonstrates failure reporting

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

function! TestPassingExample()
  call TestAssert(1 == 1, 'This test should pass', 'PassingTest')
endfunction

function! TestFailingExample()
  call TestAssert(1 == 2, 'This test should fail', 'FailingTest')
  call TestAssert('hello' == 'world', 'This should also fail', 'FailingTest')
endfunction

function! RunTestModule()
  let g:test_results = {'run': 0, 'passed': 0, 'failed': 0, 'details': []}
  
  call TestPassingExample()
  call TestFailingExample()
  
  if exists("g:test_temp_dir")
    let results = []
    call add(results, "TESTS_RUN: " . g:test_results.run)
    call add(results, "TESTS_PASSED: " . g:test_results.passed)
    call add(results, "TESTS_FAILED: " . g:test_results.failed)
    call writefile(results, g:test_temp_dir . "/test_results.txt")
  endif
  
  echom "TESTS_RUN: " . g:test_results.run
  echom "TESTS_PASSED: " . g:test_results.passed
  echom "TESTS_FAILED: " . g:test_results.failed
  
  if g:test_results.failed > 0
    for detail in g:test_results.details
      if match(detail, 'FAIL') != -1
        echom detail
      endif
    endfor
  endif
endfunction