" Run a workflow command, validate no errors, and check the buffer name and
" directory.
function! RunWorkflowAndValidateBuffer(workflow_command, expected_directory, expected_filename)
  call AssertDoesNotThrow(a:workflow_command)
  call AssertBufferInDirectory(a:expected_directory)
  call AssertBufferName(a:expected_filename)
endfunction

function! TestFileCreation()
  " Ensure workflow directories do not exist before test
  call AssertDirectoryNotExists(g:test_workspace . '/date_and_title')
  call AssertDirectoryNotExists(g:test_workspace . '/date_and_no_title')
  call AssertDirectoryNotExists(g:test_workspace . '/no_date_and_title')

  call SetupTestConfig()
  enew!

  let formatted_date = strftime(g:workflow_template_date_format)

  " Test all the necessary directories are created
  call AssertDirectoryExists(g:test_workspace . '/date_and_title')
  call AssertDirectoryExists(g:test_workspace . '/date_and_no_title')
  call AssertDirectoryExists(g:test_workspace . '/no_date_and_title')

  " Test file creation with different workflow configurations
  call RunWorkflowAndValidateBuffer("DateAndTitle test title",
        \ g:test_workspace . '/date_and_title',
        \ formatted_date . '-test-title.md')
  call RunWorkflowAndValidateBuffer("DateAndNoTitle",
        \ g:test_workspace . '/date_and_no_title',
        \ formatted_date . '.txt')
  call RunWorkflowAndValidateBuffer("NoDateAndTitle test title",
        \ g:test_workspace . '/no_date_and_title',
        \ 'test-title.md')

  " Test creating a file without a title in a workflow that requires it
  call AssertThrows("NoDateAndTitle", 'title',
        \ 'Should fail due to missing title in workflow that requires it')
endfunction
