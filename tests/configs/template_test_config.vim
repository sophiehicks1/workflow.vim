" Configuration for template_test.vim
" Sets up template testing environment

" Set up date format for consistent testing
if !exists("g:workflow_template_date_format")
  let g:workflow_template_date_format = '%Y-%m-%d %H:%M:%S'
endif

" Ensure clean state for testing
if exists("g:struct_workflows")
  unlet g:struct_workflows
endif

" Set up any template-specific test configurations
let g:test_template_formats = ['md', 'html', 'txt', 'xml']