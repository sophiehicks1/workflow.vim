" Configuration for validation_test.vim  
" Sets up validation and error testing environment

" Ensure clean state for testing
if exists("g:struct_workflows")
  unlet g:struct_workflows  
endif

" Set up error tracking for validation tests
let g:test_validation_errors = []

" Helper function to capture validation errors
function! CaptureValidationError(error)
  if !exists("g:test_validation_errors")
    let g:test_validation_errors = []
  endif
  call add(g:test_validation_errors, a:error)
endfunction

" Clear validation errors
function! ClearValidationErrors()
  let g:test_validation_errors = []
endfunction