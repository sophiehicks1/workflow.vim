" Configuration for core_functionality_test.vim
" Sets up test environment and common configurations

" Set up date format for testing
if !exists("g:workflow_template_date_format")
  let g:workflow_template_date_format = '%Y-%m-%d'
endif

" Ensure clean state for testing
if exists("g:struct_workflows")
  unlet g:struct_workflows
endif

function! SetupTestConfig()
  let g:struct_workflows = {
        \   'DateAndTitle': {
        \     'root': g:test_workspace . '/date_and_title',
        \     'ext': 'md',
        \     'date': 1,
        \     'mandatory-title': 1,
        \   },
        \   'DateAndNoTitle': {
        \     'root': g:test_workspace . '/date_and_no_title',
        \     'ext': 'txt',
        \     'date': 1,
        \     'mandatory-title': 0,
        \   },
        \   'NoDateAndTitle': {
        \     'root': g:test_workspace . '/no_date_and_title',
        \     'ext': 'md',
        \     'date': 0,
        \     'mandatory-title': 1,
        \   },
        \ }
  call struct#initialize()
endfunction
