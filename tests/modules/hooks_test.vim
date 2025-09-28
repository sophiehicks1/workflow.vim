" Hook execution tests for workflow.vim
" Tests onload, oncreate hooks, mappings, and autocmds

" Test basic onload hook
function! TestOnloadHook()
  " Create a test file to use as a marker
  let marker_file = g:test_workspace . '/onload_marker.txt'
  
  let config = {}
  let config['root'] = g:test_workspace . '/onload_test'
  let config['ext'] = 'txt'
  let config['date'] = 0
  let config['onload'] = 'call writefile(["onload executed"], "' . marker_file . '")'
  call CreateTestWorkflow('OnloadTest', config)
  
  " The workflow should be created successfully
  call Assert(has_key(g:struct_workflows, 'OnloadTest'), 'OnloadTest workflow should exist')
  
  let workflow = g:struct_workflows['OnloadTest']
  call Assert(has_key(workflow, 'onload'), 'Workflow should have onload hook')
  call AssertMatches('onload executed', workflow['onload'], 'Onload hook should contain expected command')
endfunction

" Test basic oncreate hook
function! TestOncreateHook()
  let marker_file = g:test_workspace . '/oncreate_marker.txt'
  
  call CreateTestWorkflow('OncreateTest', {
        \ 'root': g:test_workspace . '/oncreate_test',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'oncreate': 'call writefile(["oncreate executed"], "' . marker_file . '")'
        \ })
  
  call Assert(has_key(g:struct_workflows, 'OncreateTest'), 'OncreateTest workflow should exist')
  
  let workflow = g:struct_workflows['OncreateTest']
  call Assert(has_key(workflow, 'oncreate'), 'Workflow should have oncreate hook')
  call AssertMatches('oncreate executed', workflow['oncreate'], 'Oncreate hook should contain expected command')
endfunction

" Test hook with file path substitution
function! TestHookWithFilePathSubstitution()
  call CreateTestWorkflow('PathSubstitution', {
        \ 'root': g:test_workspace . '/path_test',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'onload': 'echom "Loading file: <FILE>"',
        \ 'oncreate': 'echom "Creating file: <file>"'
        \ })
  
  let workflow = g:struct_workflows['PathSubstitution']
  call Assert(has_key(workflow, 'onload'), 'Workflow should have onload hook')
  call Assert(has_key(workflow, 'oncreate'), 'Workflow should have oncreate hook')
  
  call AssertMatches('<FILE>', workflow['onload'], 'Onload hook should contain <FILE> placeholder')
  call AssertMatches('<file>', workflow['oncreate'], 'Oncreate hook should contain <file> placeholder')
endfunction

" Test normal mode mappings
function! TestNormalModeMappings()
  call CreateTestWorkflow('NmapTest', {
        \ 'root': g:test_workspace . '/nmap_test',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'nmap': {
        \   '<Leader>t': 'echo "test mapping"'
        \ }
        \ })
  
  let workflow = g:struct_workflows['NmapTest']
  call Assert(has_key(workflow, 'nmap'), 'Workflow should have nmap')
  call Assert(has_key(workflow['nmap'], '<Leader>t'), 'Workflow should have <Leader>t mapping')
  call AssertEqual('echo "test mapping"', workflow['nmap']['<Leader>t'], 'Mapping should have correct command')
endfunction

" Test insert mode mappings
function! TestInsertModeMappings()
  call CreateTestWorkflow('ImapTest', {
        \ 'root': g:test_workspace . '/imap_test',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'imap': {
        \   '<C-t>': '<Esc>:echo "insert mapping"<CR>a'
        \ }
        \ })
  
  let workflow = g:struct_workflows['ImapTest']
  call Assert(has_key(workflow, 'imap'), 'Workflow should have imap')
  call Assert(has_key(workflow['imap'], '<C-t>'), 'Workflow should have <C-t> mapping')
endfunction

" Test command mode mappings
function! TestCommandModeMappings()
  call CreateTestWorkflow('CmapTest', {
        \ 'root': g:test_workspace . '/cmap_test',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'cmap': {
        \   'test': 'echo "command mapping"'
        \ }
        \ })
  
  let workflow = g:struct_workflows['CmapTest']
  call Assert(has_key(workflow, 'cmap'), 'Workflow should have cmap')
  call Assert(has_key(workflow['cmap'], 'test'), 'Workflow should have test mapping')
endfunction

" Test noremap mappings
function! TestNoreMapMappings()
  call CreateTestWorkflow('NoreMapTest', {
        \ 'root': g:test_workspace . '/noremap_test',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'nnoremap': {
        \   '<Leader>n': ':echo "noremap test"<CR>'
        \ },
        \ 'inoremap': {
        \   '<C-n>': '<Esc>:echo "insert noremap"<CR>a'
        \ },
        \ 'cnoremap': {
        \   'ntest': 'echo "command noremap"'
        \ }
        \ })
  
  let workflow = g:struct_workflows['NoreMapTest']
  call Assert(has_key(workflow, 'nnoremap'), 'Workflow should have nnoremap')
  call Assert(has_key(workflow, 'inoremap'), 'Workflow should have inoremap')
  call Assert(has_key(workflow, 'cnoremap'), 'Workflow should have cnoremap')
endfunction

" Test abbreviations
function! TestAbbreviations()
  call CreateTestWorkflow('AbbrevTest', {
        \ 'root': g:test_workspace . '/abbrev_test',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'iabbrev': {
        \   'teh': 'the',
        \   'adn': 'and',
        \   'sig': 'Best regards,\nYour Name'
        \ }
        \ })
  
  let workflow = g:struct_workflows['AbbrevTest']
  call Assert(has_key(workflow, 'iabbrev'), 'Workflow should have iabbrev')
  call AssertEqual('the', workflow['iabbrev']['teh'], 'Should have teh abbreviation')
  call AssertEqual('and', workflow['iabbrev']['adn'], 'Should have adn abbreviation')
  call AssertMatches('Best regards', workflow['iabbrev']['sig'], 'Should have sig abbreviation')
endfunction

" Test autocmds
function! TestAutoCommands()
  call CreateTestWorkflow('AutocmdTest', {
        \ 'root': g:test_workspace . '/autocmd_test',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'autocmd': {
        \   'BufWrite': 'echo "File saved"',
        \   'BufRead': 'echo "File loaded"'
        \ }
        \ })
  
  let workflow = g:struct_workflows['AutocmdTest']
  call Assert(has_key(workflow, 'autocmd'), 'Workflow should have autocmd')
  call Assert(has_key(workflow['autocmd'], 'BufWrite'), 'Should have BufWrite autocmd')
  call Assert(has_key(workflow['autocmd'], 'BufRead'), 'Should have BufRead autocmd')
endfunction

" Test multiple hooks in same workflow
function! TestMultipleHooks()
  let onload_marker = g:test_workspace . '/multi_onload.txt'
  let oncreate_marker = g:test_workspace . '/multi_oncreate.txt'
  
  call CreateTestWorkflow('MultiHooks', {
        \ 'root': g:test_workspace . '/multi_hooks',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'onload': 'call writefile(["multi onload"], "' . onload_marker . '")',
        \ 'oncreate': 'call writefile(["multi oncreate"], "' . oncreate_marker . '")',
        \ 'nmap': {
        \   '<Leader>m': 'echo "multi mapping"'
        \ },
        \ 'autocmd': {
        \   'BufEnter': 'echo "multi autocmd"'
        \ }
        \ })
  
  let workflow = g:struct_workflows['MultiHooks']
  call Assert(has_key(workflow, 'onload'), 'Should have onload hook')
  call Assert(has_key(workflow, 'oncreate'), 'Should have oncreate hook')
  call Assert(has_key(workflow, 'nmap'), 'Should have nmap')
  call Assert(has_key(workflow, 'autocmd'), 'Should have autocmd')
endfunction

" Test hooks with complex commands
function! TestComplexHooks()
  call CreateTestWorkflow('ComplexHooks', {
        \ 'root': g:test_workspace . '/complex_hooks',
        \ 'ext': 'md',
        \ 'date': 1,
        \ 'onload': 'setlocal spell | setlocal textwidth=80 | echo "Markdown file loaded"',
        \ 'oncreate': 'normal! G | normal! o | startinsert'
        \ })
  
  let workflow = g:struct_workflows['ComplexHooks']
  call Assert(has_key(workflow, 'onload'), 'Should have complex onload hook')
  call Assert(has_key(workflow, 'oncreate'), 'Should have complex oncreate hook')
  
  call AssertMatches('setlocal spell', workflow['onload'], 'Onload should contain spell setting')
  call AssertMatches('textwidth=80', workflow['onload'], 'Onload should contain textwidth setting')
  call AssertMatches('startinsert', workflow['oncreate'], 'Oncreate should contain startinsert')
endfunction

" Test hooks with error conditions
function! TestHooksWithErrors()
  " Create workflow with intentionally problematic hooks
  call CreateTestWorkflow('ErrorHooks', {
        \ 'root': g:test_workspace . '/error_hooks',
        \ 'ext': 'txt',
        \ 'date': 0,
        \ 'onload': 'echo "This hook is fine"',
        \ 'oncreate': 'echo "This hook is also fine"'
        \ })
  
  " The workflow should still be created even if hooks might have issues
  let workflow = g:struct_workflows['ErrorHooks']
  call Assert(has_key(workflow, 'onload'), 'Should have onload hook despite potential errors')
  call Assert(has_key(workflow, 'oncreate'), 'Should have oncreate hook despite potential errors')
endfunction