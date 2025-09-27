" Configuration for hooks_test.vim
" Sets up hook testing environment

" Ensure clean state for testing
if exists("g:struct_workflows")
  unlet g:struct_workflows
endif

" Set up variables for hook testing
let g:test_hook_results = {}

" Helper function to record hook execution
function! RecordHookExecution(hook_name, data)
  if !exists("g:test_hook_results")
    let g:test_hook_results = {}
  endif
  let g:test_hook_results[a:hook_name] = a:data
endfunction