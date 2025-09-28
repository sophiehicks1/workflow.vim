" Template functionality tests for workflow.vim
" Tests template processing, variable substitution, and template loading

" Test template variable substitution
function! TestTemplateVariableSubstitution()
  " Create a test template with variables
  let template_path = g:test_workspace . '/test_template.md'
  call CreateTestFile(template_path, "Title: {{{ b:title }}}\nDate: {{{ b:date }}}\n\nContent here...")
  
  call CreateTestWorkflow('TemplateTest', {
        \ 'root': g:test_workspace . '/template_files',
        \ 'ext': 'md',
        \ 'template': template_path,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  " Verify template file exists
  call AssertFileExists(template_path, 'Template file should exist')
  
  " Verify workflow has template configured
  let workflow = g:struct_workflows['TemplateTest']
  call AssertEqual(template_path, workflow['template'], 'Template path should be set')
endfunction

" Test template with complex content
function! TestTemplateComplexContent()
  let template_path = g:test_workspace . '/complex_template.html'
  let template_content = join([
        \ '<html>',
        \ '<head><title>{{{ b:title }}}</title></head>',
        \ '<body>',
        \ '<h1>{{{ b:title }}}</h1>',
        \ '<p>Created on: {{{ b:date }}}</p>',
        \ '<div class="content">',
        \ '  <!-- Content goes here -->',
        \ '</div>',
        \ '</body>',
        \ '</html>'
        \ ], "\n")
  
  call CreateTestFile(template_path, template_content)
  
  call CreateTestWorkflow('HtmlTemplate', {
        \ 'root': g:test_workspace . '/html_files',
        \ 'ext': 'html',
        \ 'template': template_path,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  call AssertFileExists(template_path, 'HTML template should exist')
  
  " Check template content
  let content = ReadTestFile(template_path)
  call AssertMatches('{{{ b:title }}}', content, 'Template should contain title variable')
  call AssertMatches('{{{ b:date }}}', content, 'Template should contain date variable')
endfunction

" Test template with no variables
function! TestTemplateWithoutVariables()
  let template_path = g:test_workspace . '/static_template.txt'
  let template_content = join([
        \ 'This is a static template',
        \ 'with no variables to substitute.',
        \ '',
        \ 'Just plain text content.'
        \ ], "\n")
  
  call CreateTestFile(template_path, template_content)
  
  call CreateTestWorkflow('StaticTemplate', {
        \ 'root': g:test_workspace . '/static_files',
        \ 'ext': 'txt',
        \ 'template': template_path,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  call AssertFileExists(template_path, 'Static template should exist')
  
  let content = ReadTestFile(template_path)
  call AssertMatches('static template', content, 'Template should contain static content')
  call AssertNotEqual('', content, 'Template content should not be empty')
endfunction

" Test template with markdown format
function! TestMarkdownTemplate()
  let template_path = g:test_workspace . '/markdown_template.md'
  let template_content = join([
        \ '# {{{ b:title }}}',
        \ '',
        \ 'Date: {{{ b:date }}}',
        \ '',
        \ '## Overview',
        \ '',
        \ 'Write your content here...',
        \ '',
        \ '## Notes',
        \ '',
        \ '- Item 1',
        \ '- Item 2',
        \ '- Item 3',
        \ '',
        \ '## References',
        \ '',
        \ '1. Reference 1',
        \ '2. Reference 2'
        \ ], "\n")
  
  call CreateTestFile(template_path, template_content)
  
  call CreateTestWorkflow('MarkdownBlog', {
        \ 'root': g:test_workspace . '/blog_posts',
        \ 'ext': 'md',
        \ 'template': template_path,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  call AssertFileExists(template_path, 'Markdown template should exist')
  
  let content = ReadTestFile(template_path)
  call AssertMatches('# {{{ b:title }}}', content, 'Template should contain title header')
  call AssertMatches('Date: {{{ b:date }}}', content, 'Template should contain date field')
  call AssertMatches('## Overview', content, 'Template should contain sections')
endfunction

" Test workflow with missing template file
function! TestWorkflowWithMissingTemplate()
  let missing_template = g:test_workspace . '/nonexistent_template.md'
  
  " Ensure template doesn't exist
  call AssertFileNotExists(missing_template, 'Template should not exist initially')
  
  " Create workflow with missing template (should not fail during setup)
  call CreateTestWorkflow('MissingTemplate', {
        \ 'root': g:test_workspace . '/missing_template_files',
        \ 'ext': 'md',
        \ 'template': missing_template,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  " Workflow should exist even with missing template
  call Assert(has_key(g:struct_workflows, 'MissingTemplate'), 'Workflow should exist even with missing template')
endfunction

" Test template date format configuration
function! TestTemplateDateFormat()
  " Test default date format
  call AssertExists('g:workflow_template_date_format', 'Date format should be configured')
  call AssertNotEqual('', g:workflow_template_date_format, 'Date format should not be empty')
  
  " Store original format
  let original_format = g:workflow_template_date_format
  
  " Test custom date format
  let g:workflow_template_date_format = '%d/%m/%Y'
  call AssertEqual('%d/%m/%Y', g:workflow_template_date_format, 'Custom date format should be set')
  
  " Restore original format
  let g:workflow_template_date_format = original_format
endfunction

" Test template with special characters
function! TestTemplateWithSpecialCharacters()
  let template_path = g:test_workspace . '/special_template.txt'
  let template_content = join([
        \ 'Title: "{{{ b:title }}}"',
        \ 'Created: {{{ b:date }}}',
        \ '',
        \ 'Special chars: !@#$%^&*()_+-=[]{}|;:",.<>?',
        \ 'Unicode: α β γ δ ε',
        \ 'Quotes: "double" and ''single''',
        \ 'Backslashes: \\ \n \t \r',
        \ ], "\n")
  
  call CreateTestFile(template_path, template_content)
  
  call CreateTestWorkflow('SpecialChars', {
        \ 'root': g:test_workspace . '/special_files',
        \ 'ext': 'txt',
        \ 'template': template_path,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  call AssertFileExists(template_path, 'Template with special characters should exist')
  
  let content = ReadTestFile(template_path)
  call AssertMatches('Special chars:', content, 'Template should contain special characters')
  call AssertMatches('Unicode:', content, 'Template should handle unicode')
endfunction

" Test multiple templates for different workflows
function! TestMultipleTemplates()
  " Create blog template
  let blog_template = g:test_workspace . '/blog_template.md'
  call CreateTestFile(blog_template, "# {{{ b:title }}}\n\n{{{ b:date }}}\n\nBlog content...")
  
  " Create note template  
  let note_template = g:test_workspace . '/note_template.txt'
  call CreateTestFile(note_template, "Note: {{{ b:title }}}\nDate: {{{ b:date }}}\n\nNotes...")
  
  call CreateTestWorkflow('Blog', {
        \ 'root': g:test_workspace . '/blog',
        \ 'ext': 'md',
        \ 'template': blog_template,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  call CreateTestWorkflow('Notes', {
        \ 'root': g:test_workspace . '/notes',
        \ 'ext': 'txt', 
        \ 'template': note_template,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  call AssertFileExists(blog_template, 'Blog template should exist')
  call AssertFileExists(note_template, 'Note template should exist')
  
  call AssertEqual(blog_template, g:struct_workflows['Blog']['template'], 'Blog should use correct template')
  call AssertEqual(note_template, g:struct_workflows['Notes']['template'], 'Notes should use correct template')
endfunction