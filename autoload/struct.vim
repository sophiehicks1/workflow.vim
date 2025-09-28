if exists("g:did_autoload_struct")
  finish
endif
let g:did_autoload_struct = 1

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

function! s:has_insert_path(workflow)
  return has_key(a:workflow, 'insertPath') && (type(a:workflow['insertPath']) ==# type({}))
endfunction

function! s:periodicity(workflow)
  return has_key(a:workflow, 'period') ? a:workflow['period'] : 'daily'
endfunction

function! s:sanitize_title(title)
  let without_spaces = substitute(a:title, '[[:space:]][[:space:]]*', '-', 'g')
  let lower_case = tolower(without_spaces)
  return substitute(lower_case, '[^a-z0-9\-]', '', 'g')
endfunction

function! s:daily_date()
  return strftime('%Y-%m-%d')
endfunction

function! s:weekly_date()
  let t = localtime()
  let adj_days = strftime('%w', t) - 1
  let adj_seconds = adj_days * 24 * 3600
  return strftime('%Y-%m-%d', t - adj_seconds)
endfunction

function! s:monthly_date()
  return strftime('%Y-%m-01', localtime())
endfunction

function! s:workflow_date(workflow)
  let l:period = s:periodicity(a:workflow)
  if l:period == 'daily'
    return s:daily_date()
  elseif l:period == 'weekly'
    return s:weekly_date()
  elseif l:period == 'monthly'
    return s:monthly_date()
  end
endfunction

function! s:make_filename(workflow, title)
  let name = ''
  if s:has_date(a:workflow)
    let name = name . s:workflow_date(a:workflow)
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
  if s:has_mandatory_title(a:workflow) && !len(a:locator)
    throw "Invalid file locator '" . a:locator . "'"
  endif
  let locator = s:parse_locator(a:workflow, a:locator)
  if s:has_mandatory_title(a:workflow) && !len(locator['title'])
    throw "Invalid file locator '" . a:locator . "'"
  endif
  return fnamemodify(locator['dir'] .  s:make_filename(a:workflow, locator['title']), ':p')
endfunction

function! s:splitType()
  if !&hidden && &modified
    echom "Force setting splitType to 'split' to avoid losing unsaved changes"
    return 'split'
  else
    return ''
  endif
endfunction

function! s:newBufferCommand(splitType, path)
  if (a:splitType == 'split')
    return "new " . a:path
  else
    return "edit " . a:path
  endif
endfunction

function! s:existingBufferCommand(splitType, notesBufferNum)
  if (a:splitType == 'split')
    return "split +buffer" . a:notesBufferNum
  else
    return "buffer " . a:notesBufferNum
  endif
endfunction

" return true if a new buffer was created
function! s:openFile(path)
  let splitType = s:splitType()
  let existingBufferNum = bufnr(a:path)
  let isNewBuffer = (existingBufferNum ==# -1)
  if isNewBuffer
    let command = s:newBufferCommand(splitType, a:path)
  else
    let command = s:existingBufferCommand(splitType, existingBufferNum)
  endif
  execute command
  return isNewBuffer
endfunction

function! struct#openDir(workflowName)
  let workflow = g:struct_workflows[a:workflowName]
  let root = workflow['root']
  call s:openFile(root)
endfunction

function! s:addMappings(workflow, mapType)
  if has_key(a:workflow, a:mapType)
    let mappings = a:workflow[a:mapType]
    for mapping in keys(mappings)
      execute a:mapType . ' <buffer> ' . mapping . ' ' . mappings[mapping]
    endfor
  end
endfunction

function! s:executeHooks(workflow, path, isNewFile)
  if has_key(a:workflow, 'onload')
    execute substitute(a:workflow['onload'], '<[Ff][Ii][Ll][Ee]>', a:path, 'g')
  end
  call s:addMappings(a:workflow, 'imap')
  call s:addMappings(a:workflow, 'cmap')
  call s:addMappings(a:workflow, 'nmap')
  call s:addMappings(a:workflow, 'inoremap')
  call s:addMappings(a:workflow, 'cnoremap')
  call s:addMappings(a:workflow, 'nnoremap')
  call s:addMappings(a:workflow, 'iabbrev')
  if a:isNewFile && has_key(a:workflow, 'oncreate')
    execute substitute(a:workflow['oncreate'], '<[Ff][Ii][Ll][Ee]>', a:path, 'g')
  end
endfunction

function! s:setAutocmds(workflow)
  if has_key(a:workflow, 'autocmd')
    let cmds = a:workflow['autocmd']
    for key in keys(cmds)
      execute 'au! '.key.' <buffer> '.cmds[key]
    endfor
  end
endfunction

function! s:makeSubstitutions()
  let curr = 0
  let subspattern = '{{{\(\(}\?}\?[^}]\)*\)}}}'
  while curr <= line("$")
    let currline = getline(curr)
    while match(currline, subspattern) != -1
      let list = matchlist(currline, subspattern)
      call setline(curr, substitute(currline, '\V'.list[0], '\='.list[1], ''))
      let currline = getline(curr)
    endwhile
    let curr = curr + 1
  endwhile
endfunction

function! s:loadTemplate(workflow)
  if has_key(a:workflow, 'template')
    execute "norm! V:read ".a:workflow['template']."kdd"
  end
endfunction

function! s:applyTemplate(workflow, locator)
  let datestr = system("date +'".g:workflow_template_date_format."'")
  let b:date = strpart(datestr, 0, len(datestr) -1)
  let b:title = s:parse_locator(a:workflow, a:locator).title
  call s:loadTemplate(a:workflow)
  call s:makeSubstitutions()
endfunction

function! s:openAndPostProcessPath(workflow, path, locator)
  let isNewFile = (! filereadable(a:path))
  let isNewBuffer = s:openFile(a:path)
  if (isNewFile && isNewBuffer)
    call s:applyTemplate(a:workflow, a:locator)
  end
  call s:executeHooks(a:workflow, a:path, isNewFile)
  call s:setAutocmds(a:workflow)
endfunction

function! s:openAndPostProcess(workflow, locator)
  let path = fnamemodify(s:path(a:workflow, a:locator), ':p')
  return s:openAndPostProcessPath(a:workflow, path, a:locator)
endfunction

function! struct#openFile(workflowName, ...)
  let locator = len(a:000) ? a:1 : ''
  let workflow = g:struct_workflows[a:workflowName]
  try
    call s:openAndPostProcess(workflow, locator)
  catch /Invalid file locator '.*/
    throw "Workflow '".a:workflowName."' requires a title"
  endtry
endfunction

" Unused args are so that this function follows the same arg pattern as the
" other user exposed functions
function! struct#loadHooks(workflowName, ...)
  let workflow = g:struct_workflows[a:workflowName]
  call s:executeHooks(workflow, expand("%"), 0)
  call s:setAutocmds(workflow)
endfunction

" Unused args are so that this function follows the same arg pattern as the
" other user exposed functions
function! struct#createHooks(workflowName, ...)
  let workflow = g:struct_workflows[a:workflowName]
  call s:executeHooks(workflow, expand("%"), 1)
  call s:setAutocmds(workflow)
endfunction

function! s:is_windows()
  if !exists("g:struct_is_windows")
    let g:struct_is_windows = (match(exepath("find"), "\c.*\.exe$") != -1)
  endif
  return g:struct_is_windows
endfunction

function! struct#matchingFiles(workflowName, pattern)
  let workflow = g:struct_workflows[a:workflowName]
  let dir = fnamemodify(workflow['root'], ':p')
  let paths_out = ""
  if s:is_windows()
    let paths_out = system('dir "'.dir.'\*'.a:pattern.'* /b/s')
  else
    let paths_out = system("find '".dir."' -name "."'*".a:pattern."*' -type f")
  endif
  let paths = split(substitute(paths_out, "\/\/", "/", "g"), "\n")
  return map(paths, "substitute(v:val, '".dir."', '', '')")
endfunction

function! struct#insertPathAutoComplete(argLead, cmdLine, cursorPos)
  let workflowName = strpart(a:cmdLine, 0, match(a:cmdLine, 'InsertPath'))
  return struct#matchingFiles(workflowName, a:argLead)
endfunction

function! s:matchWorkflow(string)
  for workflow in keys(g:struct_workflows)
    if match(a:string, '^' . workflow) != -1
      return workflow
    endif
  endfor
  return -1
endfunction

" This only works for workflows which DO NOT automatically add a date (ie.
" where workflow['date'] == 0)
function! struct#openFileAutoComplete(argLead, cmdLine, cursorPos)
  let workflowName =  s:matchWorkflow(strpart(a:cmdLine, 0, match(a:cmdLine, ' ')))
  let paths = struct#matchingFiles(workflowName, a:argLead)
  return map(paths, "substitute(v:val, '\.". g:struct_workflows[workflowName]['ext'] ."$', '', '')")
endfunction

function! struct#insertPath(workflowName, path)
  let bak = @a
  let filePath = a:path
  if match(filePath, "^/.*") == -1
    let workflow = g:struct_workflows[a:workflowName]
    let absoluteDir = fnamemodify(workflow['root'], ':p')
    let filePath = fnamemodify(absoluteDir . filePath, ':p')
  endif
  if filereadable(filePath)
    let @a = filePath
    normal! "ap
    let @a = bak
  else
    throw "Invalid path: ".a:path
  endif
endfunction

function! struct#grep(workflowName, query)
  let workflow = g:struct_workflows[a:workflowName]
  execute "grep -ri '" . a:query . "' " . workflow['root']
endfunction

function! s:makeExCommand(name, command, function, withArgs)
  let nargs = a:withArgs ? '?' : '0'
  let command = a:name.a:command
  let argList = "'".a:name."'".(a:withArgs ? ', <f-args>' : '')
  if (a:withArgs && s:has_date(g:struct_workflows[a:name]) == 0)
    let complOpts = '-complete=customlist,struct#openFileAutoComplete '
  else
    let complOpts = ''
  endif
  execute 'command! -nargs='.nargs.' '.complOpts.command.' call struct#'.a:function."(".argList.")"
endfunction

function! s:setupInsertPath(name)
  let workflow = g:struct_workflows[a:name]
  if s:has_insert_path(workflow)
    let commandName = a:name.'InsertPath'
    execute 'command! -nargs=1 -complete=customlist,struct#insertPathAutoComplete '.commandName.' call struct#insertPath("'.a:name.'", <f-args>)'
    let config = workflow['insertPath']
    if has_key(config, 'globalImap')
      execute 'inoremap ' . config['globalImap'] . ' <c-o>:'.commandName.' '
    endif
  endif
endfunction

function! s:makeExCommands(name)
  call s:makeExCommand(a:name, '', 'openFile', 1)
  call s:makeExCommand(a:name, 'List', 'openDir', 0)
  call s:makeExCommand(a:name, 'Grep', 'grep', 1)
  call s:makeExCommand(a:name, 'LoadHooks', 'loadHooks', 0)
  call s:makeExCommand(a:name, 'CreateHooks', 'createHooks', 0)
  call s:setupInsertPath(a:name)
endfunction

function! s:rootDoesNotExist(workflow)
  return glob(fnamemodify(a:workflow['root'], ':p')) == ''
endfunction

function! s:rootIsNotADirectory(workflow)
  return !isdirectory(fnamemodify(a:workflow['root'], ":p"))
endfunction

function! s:validateRoot(workflow, errors)
  if s:rootDoesNotExist(a:workflow)
    call mkdir(fnamemodify(a:workflow['root'], ':p'), 'p')
  endif
  if s:rootIsNotADirectory(a:workflow)
    call add(a:errors, "root directory '" . a:workflow['root'] . "'is not a directory")
  endif
endfunction

function! s:validateWorkflowName(name, errors)
  if len(a:name) == 0
    call add(a:errors, "invalid workflow name. Name must be non-empty")
  endif
  if match(a:name, '^[A-Z][a-zA-Z0-9]*$') == -1
    call add(a:errors, "name must start with an uppercase letter, and only contain alphanumeric chars.")
  endif
endfunction

function! s:validateWorkflow(name)
  let workflow = g:struct_workflows[a:name]
  let errors = []
  call s:validateWorkflowName(a:name, errors)
  if !has_key(workflow, 'ext')
    call add(errors, "does not contain the mandatory 'ext' key")
  endif
  if has_key(workflow, 'root')
    call s:validateRoot(workflow, errors)
  else
    call add(errors, "does not contain the mandatory 'root' key")
  endif
  return errors
endfunction

function! s:initializeWorkflow(name)
  let errors = s:validateWorkflow(a:name)
  if len(errors) > 0
    for error in errors
      throw "Invalid workflow '".a:name."' - ".error
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
