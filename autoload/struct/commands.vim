function! s:take_first(args)
  return [a:args[0], a:args[1:]]
endfunction

function! s:convert_arguments_to_map(args)
  let args = copy(a:args)
  let values = {}
  let current_var = ''
  let current_val = ''
  while len(args)
    let [arg, args] = s:take_first(args)
    if arg =~# '^--\(\w\+\)'
      if len(current_var) && len(current_val)
        let values[current_var] = substitute(current_val, '^ ', '', '')
      elseif len(current_var)
        let values[current_var] = v:true
      endif
      let current_var = substitute(arg, '^--\(\w\+\).*', '\1', '')
      let current_val = ''
    else
      if !len(current_var)
        throw 'Unexpected argument: ' . arg
      endif
      let current_val = current_val . ' ' . arg
    endif
  endwhile
  if len(current_var) && len(current_val)
    let values[current_var] = substitute(current_val, '^ ', '', '')
  endif
  return values
endfunction

function! s:check_mandatory_variables(variables, values)
  for [var_name, var_config] in items(a:variables)
    if !has_key(a:values, var_name)
      if var_config.optional ==# v:false
        throw 'Missing mandatory variable: --' . var_name
      endif
    endif
  endfor
endfunction

function! s:check_unexpected_arguments(variables, arg_values)
  let variable_names = keys(a:variables)
  for [arg_name, _] in items(a:arg_values)
    if index(variable_names, arg_name) == -1
      throw 'Unexpected variable: --' . arg_name
    endif
  endfor
endfunction

function! s:parse_command_arguments(workflow_name, args)
  let variables = struct#utils#workflow_variables(a:workflow_name)
  let variable_names = keys(variables)
  let values = {}
  if len(a:args)
    if len(variable_names) == 1 && a:args[0] !~# '^--\(\w\+\)'
      let values[variable_names[0]] = join(a:args, ' ')
    else
      let values = s:convert_arguments_to_map(a:args)
    endif
  endif
  call s:check_mandatory_variables(variables, values)
  call s:check_unexpected_arguments(variables, values)
  return values
endfunction

function! s:open_workflow_command(workflow_name, ...)
  let args = a:000
  let values = s:parse_command_arguments(a:workflow_name, args)
  call struct#open(a:workflow_name, values)
endfunction

function! s:workflow_create_completion_function(workflow_name)
  let func_name = 'StructAutogen_complete_' . a:workflow_name . '_Create'
  execute 'function! ' . func_name . '(ArgLead, CmdLine, CursorPos) abort'
        \ . "\n  let variables = struct#utils#workflow_variables('" . a:workflow_name . "')"
        \ . "\n  let completions = map(keys(variables), '\"--\" . v:val')"
        \ . "\n  return filter(completions, 'v:val =~ \"^\" . a:ArgLead')"
        \ . "\nendfunction"
  return func_name
endfunction

function! s:workflow_open_completion_function(workflow_name)
  let func_name = 'StructAutogen_complete_' . a:workflow_name . '_Open'
  execute 'function! ' . func_name . '(ArgLead, CmdLine, CursorPos) abort'
        \ . "\n  let workflow_root = struct#utils#workflow_root('" . a:workflow_name . "')"
        \ . "\n  let files = systemlist('find ' . workflow_root . ' -type f | sort')"
        \ . "\n  let files = map(files, 'substitute(v:val, \"^\" . workflow_root, \"\", \"\")')"
        \ . "\n  return filter(files, 'v:val =~ \"^\" . a:ArgLead')"
        \ . "\nendfunction"
  return func_name
endfunction


function! struct#commands#initialize_workflow_commands(workflow_name)
  let create_compl_func = s:workflow_create_completion_function(a:workflow_name)
  execute 'command! -complete=customlist,' . create_compl_func . ' -nargs=* ' . a:workflow_name .
        \ ' call <SID>open_workflow_command("' . a:workflow_name . '", <f-args>)'
  let open_compl_func = s:workflow_open_completion_function(a:workflow_name)
  execute 'command! -complete=customlist,' . open_compl_func . ' -nargs=1 ' .
        \ a:workflow_name . 'Open call struct#open#open_existing_relative_to_workflow_root("' . a:workflow_name . '", <f-args>)'
endfunction

function! s:complete_relative_repo_root(ArgLead, CmdLine, CursorPos)
  let repo_root = struct#utils#repo_root()
  let files = systemlist('find ' . repo_root . ' -type f | sort')
  let files = map(files, 'substitute(v:val, "^" . repo_root . "/", "", "")')
  return filter(files, 'v:val =~ "^" . a:ArgLead')
endfunction

function! struct#commands#initialize_generic_commands()
  command! -nargs=1 -complete=customlist,s:complete_relative_repo_root WorkflowOpen call struct#open#open_existing_relative_to_repo_root(<f-args>)
endfunction
