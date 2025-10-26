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
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'Greet': {
        \   'root': 'greet/',
        \   'ext': 'md',
        \   'template': 'templates/greet.md',
        \   'title_format': '%Y-%m-%d $who',
        \ },
        \ })

  " Define a custom function to be used in the template
  function! CustomGreeting(name)
    return 'Hello, '. a:name .'!'
  endfunction

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

  delfunction! CustomGreeting
endfunction

function! TestCustomFunctionMultiLineReturn()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'Greet': {
        \   'root': 'greet/',
        \   'ext': 'md',
        \   'template': 'templates/greet.md',
        \   'title_format': '%Y-%m-%d $who',
        \ },
        \ })

  " Should work with multiple lines
  function! CustomGreeting(name)
    return 'Hello, '. a:name . "!\nWelcome to Struct.vim."
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
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'ErrorTest': {
        \   'root': 'error_test/',
        \   'ext': 'md',
        \   'template': 'templates/error_test.md',
        \   'title_format': '%Y-%m-%d',
        \ },
        \ 'SyntaxErrorTest': {
        \   'root': 'syntax_error_test/',
        \   'ext': 'md',
        \   'template': 'templates/syntax_error.md',
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
  let syntax_error_message = 'Vim(call):E116: Invalid arguments for function Foo'
  let expected_syntax_error_content = ['Error executing template code: ' . syntax_error_message]
  call struct#open('SyntaxErrorTest', {})
  let buf_content = getbufline('%', 1, '$')
  call AssertDeepEqual(expected_syntax_error_content, buf_content,
        \ "File '" . bufname('%') . "' should contain the syntax error message from the template")
endfunction

function! TestTemplateWithDefaultValues()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'Page': {
        \   'root': 'pages/',
        \   'ext': 'md',
        \   'template': 'templates/defaults.md',
        \   'title_format': '$title?',
        \   'variables': {
        \     'title': { 'default': 'Untitled' },
        \   },
        \ },
        \ })

  " Open a new file without providing the optional variable
  call struct#open('Page', {})

  let buf_content = getbufline('%', 1, '$')
  let expected_content = [
        \ '# Untitled',
        \ ]

  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content with default variable value")

  call AssertEqual(1, &modified, "Buffer should be marked as modified after template expansion")
endfunction

function! TestMultiLineExpansionInTemplate()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'MultiLine': {
        \   'root': 'multiline/',
        \   'ext': 'md',
        \   'template': 'templates/multiline.md',
        \   'title_format': '%Y-%m-%d $title?',
        \   'variables': {
        \     'title': { 'default': '' },
        \   },
        \ },
        \ })

  " Open a new file that uses a variable which expands to multiple lines
  call struct#open('MultiLine', {})
  let buf_content = getbufline('%', 1, '$')
  let expected_content = [
        \ '',
        \ ]
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content with multi-line expansion")
endfunction

function! TestOptionalVariablesCanBeTestedUsingExists()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'OptionalVars': {
        \   'root': 'optional_vars/',
        \   'ext': 'md',
        \   'template': 'templates/optional_vars.md',
        \   'title_format': '%Y%m%d%H%M%S',
        \   'variables': {
        \     'optionalHeading': { 'optional': v:true },
        \   },
        \ },
        \ })

  " Open a new file without providing the optional variable
  call struct#open('OptionalVars', {})
  let buf_content = getbufline('%', 1, '$')
  let expected_content = [
        \ 'Default content',
        \ ]
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content without optional variable")

  " Clean up buffer
  execute 'bwipeout! ' . bufname('%')

  call struct#open('OptionalVars', {'$optionalHeading': 'Custom Heading'})
  let buf_content_with_var = getbufline('%', 1, '$')
  let expected_content_with_var = [
        \ '# Custom Heading',
        \ '',
        \ 'Default content',
        \ ]
  call AssertDeepEqual(expected_content_with_var, buf_content_with_var,
        \ "File '" . bufname('%') . "' does not match expected content with optional variable provided")
endfunction


" Template expansion that starts and ends with newlines (i.e. there's nothing
" on the same line as the {{{...}}}) should result in those newlines being
" removed when the expansion returns v:null
function! TestTemplateExpansionWithSurroundingNewlines()
  call struct#initialize(g:test_workspace . '/TemplateTestsRepo', {
        \ 'ExpansionNewlines': {
        \   'root': 'expansion_newlines/',
        \   'ext': 'md',
        \   'template': 'templates/expansion_newlines.md',
        \   'title_format': 'StaticTitle',
        \ },
        \ })

  " Open a new file that uses a template with surrounding newlines
  call struct#open('ExpansionNewlines', {})
  let buf_content = getbufline('%', 1, '$')
  let expected_content = [
        \ 'When template expansion code is on its own line, that line is removed if the',
        \ 'expansion returns null, but preserved if the expansion returns content',
        \ '',
        \ 'before null expansion',
        \ 'after null expansion',
        \ '',
        \ 'before contentful expansion',
        \ 'content from expansion',
        \ 'after contentful expansion',
        \ '',
        \ 'Inline template expansion code like "" that returns null',
        \ 'has no newlines removed.',
        \ ]
  call AssertDeepEqual(expected_content, buf_content,
        \ "File '" . bufname('%') . "' does not match expected content with surrounding newlines handled correctly")
endfunction
