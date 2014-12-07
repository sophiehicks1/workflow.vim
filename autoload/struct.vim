if exists("g:did_autoload_struct")
  finish
endif
let g:did_autoload_struct = 1

" TODO
" - autocomplete for ex commands
"   - 'title' should complete to '2014-12-01-title' when the workflow has
"     dates
"   - 'dir' should complete to 'directory/' when the workflow is nested
"   - 'directory/' should complete to anything inside 'directory/' when the
"     workfow is nested
"   - 'filename' should complete to 'directory/filename' when the workflow is
"     nested
" - onopen scripts (for use with DoWhat)

function! s:date()
  return substitute(system('date +%Y-%m-%d'), "\n", '', '')
endfunction

function! s:has_key(workflow, key)
  return has_key(a:workflow, a:key) && a:workflow[a:key]
endfunction

function! s:has_date(workflow)
  return s:has_key(a:workflow, 'date')
endfunction

function! s:has_mandatory_title(workflow)
  return !s:has_date(a:workflow) || s:has_key(a:workflow, 'mandatory-title')
endfunction

function! s:has_nested(workflow)
  return s:has_key(a:workflow, 'nested')
endfunction

function! s:sanitize_title(title)
  let without_spaces = substitute(a:title, '[[:space:]][[:space:]]*', '-', 'g')
  let lower_case = tolower(without_spaces)
  return substitute(lower_case, '[^a-z0-9\-]', '', 'g')
endfunction

function! s:make_filename(workflow, title)
  let name = ''
  if s:has_date(a:workflow)
    let name = name . s:date()
  endif
  let title = s:sanitize_title(a:title)
  if len(name) && len(title)
    let name = name . '-'
  endif
  let name = name . title . '.' . a:workflow['ext']
  return name
endfunction

function! s:ensure_dir_exists(dir)
  if !isdirectory(a:dir)
    call system('mkdir -p '.shellescape(a:dir))
  endif
endfunction

function! s:parse_locator(workflow, locator)
  let parts = [a:locator]
  if s:has_nested(a:workflow)
    let parts = split(a:locator, '/')
  endif
  let dir = a:workflow['root']
  if s:has_nested(a:workflow)
    let dir = dir . '/' . join(parts[0:-2], '/')
  endif
  let dir = fnamemodify(dir, ':p')
  call s:ensure_dir_exists(dir)
  return { "dir": dir, "title": parts[-1] }
endfunction

function! s:path(workflow, locator)
  let locator = s:parse_locator(a:workflow, a:locator)
  if s:has_mandatory_title(a:workflow) && !len(locator['title'])
    throw "Invalid file locator '" . a:locator . "'"
  endif
  return fnamemodify(locator['dir'] .  s:make_filename(a:workflow, locator['title']), ':p')
endfunction

function! s:safeSplitType(splitType)
  if (a:splitType ==# '') && !&hidden && &modified
    echom "Force setting splitType to 'split' to avoid losing unsaved changes"
    return 'split'
  else
    return a:splitType
  endif
endfunction

function! s:newBufferCommand(splitType, path)
  if (a:splitType == 'split')
    return "new " . a:path
  elseif (a:splitType == 'vert')
    return "vert new " . a:path
  elseif (a:splitType == 'tab')
    return "tabnew " . a:path
  else
    return "edit " . a:path
  endif
endfunction

function! s:existingBufferCommand(splitType, notesBufferNum)
  if (a:splitType == 'split')
    return "split +buffer" . a:notesBufferNum
  elseif (a:splitType == 'vert')
    return "vert split +buffer" . a:notesBufferNum
  elseif (a:splitType == 'tab')
    return "tab sb " . a:notesBufferNum
  else
    return "buffer " . a:notesBufferNum
  endif
endfunction

function! s:openFile(splitType, path)
  let splitType = s:safeSplitType(a:splitType)
  let existingBufferNum = bufnr(a:path)
  if existingBufferNum ==# -1
    let command = s:newBufferCommand(splitType, a:path)
  else
    let command = s:existingBufferCommand(splitType, existingBufferNum)
  endif 
  execute command
endfunction

function! struct#openDir(workflowName, splitType)
  let workflow = g:struct_workflows[a:workflowName]
  let root = workflow['root']
  call s:openFile(a:splitType, root)
endfunction

function! struct#openFile(workflowName, splitType, ...)
  let locator = len(a:000) ? a:1 : ''
  let workflow = g:struct_workflows[a:workflowName]
  let path = s:path(workflow, locator)
  call s:openFile(a:splitType, path)
  if has_key(workflow, 'onload')
    execute workflow['onload']
  end
endfunction

function! s:makeExCommands(name)
  execute 'command! -nargs=? '.a:name." call struct#openFile('".a:name."', '', <f-args>)"
  execute 'command! -nargs=? H'.a:name." call struct#openFile('".a:name."', 'split', <f-args>)"
  execute 'command! -nargs=? V'.a:name." call struct#openFile('".a:name."', 'vert', <f-args>)"
  execute 'command! -nargs=? T'.a:name." call struct#openFile('".a:name."', 'tab', <f-args>)"
  execute 'command! -nargs=0 '.a:name."List call struct#openDir('".a:name."', '')"
  execute 'command! -nargs=0 H'.a:name."List call struct#openDir('".a:name."', 'split')"
  execute 'command! -nargs=0 V'.a:name."List call struct#openDir('".a:name."', 'vert')"
  execute 'command! -nargs=0 T'.a:name."List call struct#openDir('".a:name."', 'tab')"
endfunction

function! s:rootIsDirectory(workflow)
  return isdirectory(fnamemodify(a:workflow['root'], ":p"))
endfunction

function! s:errorsForWorkflow(name)
  let workflow = g:struct_workflows[a:name]
  let errors = []
  if !has_key(workflow, 'ext')
    call add(errors, "does not contain the mandatory 'ext' key")
  endif
  if !has_key(workflow, 'root')
    call add(errors, "does not contain the mandatory 'root' key")
  endif
  if !s:rootIsDirectory(workflow)
    call add(errors, "root directory '".workflow['root']."' does not exist")
  endif
  return errors
endfunction

function! s:echoError(error)
  echohl WarningMsg
  echom a:error
  echohl None
endfunction

function! s:initializeWorkflow(name)
  let errors = s:errorsForWorkflow(a:name)
  if len(errors) > 0
    for error in errors
      call s:echoError("Invalid workflow '".a:name."' - ".error)
    endfor
  else
    call s:makeExCommands(a:name)
  endif
endfunction

function! struct#initialize()
  if exists("g:struct_workflows")
    for name in keys(g:struct_workflows)
      call s:initializeWorkflow(name)
    endfor
  endif
endfunction
