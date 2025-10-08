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


" TODO use journal for testing variables (like $title)
" TODO use daily for testing strftime
" TODO use... something else... for testing variables that are not in the title (if
" TODO that's a thing I want to support??)
