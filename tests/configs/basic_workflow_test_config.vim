" Configuration for basic_workflow_test.vim
" Sets up test environment and common configurations

" Set up date format for testing
if !exists("g:workflow_template_date_format")
  let g:workflow_template_date_format = '%Y-%m-%d'
endif

" Ensure clean state for testing
if exists("g:struct_workflows")
  unlet g:struct_workflows
endif