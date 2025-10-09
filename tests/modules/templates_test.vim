function! TestStaticTemplateLoading()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'Capture': {
        \   'root': 'capture/',
        \   'ext': 'md',
        \   'template': 'templates/capture.md',
        \   'title_format': '%Y-%m-%d %H%M%S',
        \ },
        \ })

  " Test that the template file was loaded correctly
  call struct#open('Capture', {})
  let buf_content = getbufline('%', 1, '$')
  let template_file = g:test_workspace . '/TemplateTestsRepo/templates/capture.md'
  let expected_content = readfile(template_file)
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content")
endfunction

function! TestMissingTemplateFile()
  call AssertThrows(
        \ function('struct#initialize', [g:test_workspace . '/TemplateTestsRepo', {
        \ 'Capture': {
        \   'root': 'capture/',
        \   'ext': 'md',
        \   'template': 'templates/missing.md',
        \   'title_format': '%Y-%m-%d %H%M%S',
        \ },
        \ }]),
        \ 'Template file not found: ' . g:test_workspace . '/TemplateTestsRepo/templates/missing.md',
        \ "Initializing with a missing template file should throw an error")
endfunction

function! TestTemplateWithVariables()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'Journal': {
        \   'root': 'journal/',
        \   'ext': 'md',
        \   'template': 'templates/journal.md',
        \   'title_format': '%Y-%m-%d $title?',
        \ },
        \ })

  " Open a new journal entry with a specific title variable
  call struct#open('Journal', {'$title': 'My First Entry'})
  let buf_content = getbufline('%', 1, '$')
  let expected_content = [
        \ '# My First Entry',
        \ '',
        \ '#journal',
        \ ]
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content with variables")
  call AssertEqual(1, &modified, "Buffer should be marked as modified after template expansion")
endfunction

function! TestNoTemplateWorkflow()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'Notes': {
        \   'root': 'notes/',
        \   'ext': 'txt',
        \   'title_format': '$title',
        \ },
        \ })

  " Open a new note without a template
  call struct#open('Notes', {'$title': 'Meeting Notes'})
  let buf_content = getbufline('%', 1, '$')
  let expected_content = ['']
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' should be empty without a template")
  call AssertEqual(0, &modified, "Buffer should not be marked as modified without a template")
endfunction

function! TestTimeInTemplate()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'Daily': {
        \   'root': 'daily/',
        \   'ext': 'md',
        \   'template': 'templates/daily.md',
        \   'title_format': '%Y-%m-%d',
        \ },
        \ })
  call struct#open('Daily', {})
  let buf_content = getbufline('%', 1, '$')
  let expected_content = [
        \ '# ' . strftime('%Y-%m-%d'),
        \ '',
        \ '[[weekly/' . strftime('%Y-W%W') . ']]',
        \ ]
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content with date")
  call AssertEqual(1, &modified, "Buffer should be marked as modified after template expansion")
endfunction

function! TestCustomFunctionInTemplate()
  " Define a custom function to be used in the template
  function! CustomGreeting()
    return 'Hello, '. g:struct_context['$who'] .'!'
  endfunction

  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'Greet': {
        \   'root': 'greet/',
        \   'ext': 'txt',
        \   'template': 'templates/greet.md',
        \   'title_format': '%Y-%m-%d $who',
        \ },
        \ })

  " Open a new greeting file with the custom function variable
  call struct#open('Greet', {'$who': 'World'})
  let buf_content = getbufline('%', 1, '$')
  let expected_content = [
        \ '# Greeting',
        \ '',
        \ 'Hello, World!',
        \ ]
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content with custom function")
  call AssertEqual(1, &modified, "Buffer should be marked as modified after template expansion")

  " Should work with multiple lines
  function! CustomGreeting()
    return 'Hello, '. g:struct_context['$who'] . "!\nWelcome to Struct.vim."
  endfunction
  call struct#open('Greet', {'$who': 'Alice'})
  let buf_content = getbufline('%', 1, '$')
  let expected_content = [
        \ '# Greeting',
        \ '',
        \ 'Hello, Alice!',
        \ 'Welcome to Struct.vim.',
        \ ]
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content with multiple lines from custom function")
  call AssertEqual(1, &modified, "Buffer should be marked as modified after template expansion")

  " Clean up by removing the custom function
  delfunction! CustomGreeting
endfunction

function! TestErrorsInTemplateExpansion()
  " thrown errors prppagate correctly
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'ErrorTest': {
        \   'root': 'error_test/',
        \   'ext': 'md',
        \   'template': 'templates/error_test.md',
        \   'title_format': '%Y-%m-%d',
        \ },
        \ })

  " assert that error thrown is shown in buffer content
  let error_message = 'This is a test error from template'
  let expected_content = ['Error executing template code: ' . error_message]
  call struct#open('ErrorTest', {})
  let buf_content = getbufline('%', 1, '$')
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' should contain the error message from the template")

  " syntax error in template isn't silently swallowed
endfunction

" things to test
" - functions that throw (errors should propagate)
"
" Test default values for missing optional variables
" - test title setting behaviour
" - test template behaviour
" - test template with unset optional variable and no default (default value
"   for default?)

" FIXME autoload/struct.vim is getting messy... refactor
