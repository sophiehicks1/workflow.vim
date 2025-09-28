" Test module that demonstrates failure reporting using shared framework helpers

function! TestPassingExample()
  call Assert(1 == 1, 'This test should pass')
endfunction

function! TestFailingExample()
  call Assert(1 == 2, 'This test should fail')
endfunction
