function! struct#templates#execute(workflow_name, lines)
  let l:workflow = struct#utils#get_workflow(a:workflow_name)
  let l:variables = copy(workflow.title_format.variables)
  " extract variables and pass them in as a: variables
  let result = ''
  try
    let func_name = 'TemplateFunc' . strftime('%s') . rand()
    let func_vars = '(' . join(map(l:variables, {_, v -> substitute(v, '[?$]', '', 'g')}), ', ') . ')'
    let func_lines = 'function! ' . func_name . func_vars . "\n" . a:lines . "\nendfunction"
    execute func_lines
    let call_vars = map(l:variables, {_, v -> g:struct_context['$' . v]})
    let result = call(func_name, call_vars)
  catch
    let result = 'Error executing template code: ' . v:exception
  finally
    if exists('*' . func_name)
      execute 'delfunction! ' . func_name
    endif
  endtry
  return result
endfunction

function! struct#templates#render(workflow_name)
  silent! %s/{{{\(.\{-}\)}}}/\=struct#templates#execute(a:workflow_name, submatch(1))/ge
  if line('$') > 1 || getline(1) !=# ''
    " mark buffer as modified if content was added
    setlocal modified
  else
    setlocal nomodified
  endif
endfunction

function! struct#templates#apply(workflow_name)
  let l:workflow = struct#utils#get_workflow(a:workflow_name)
  if has_key(l:workflow, 'template')
    let template_path = simplify(fnamemodify(g:struct_repo_root . '/' . l:workflow.template, ':p'))
    let au_glob_path = substitute(l:workflow.root . '/*' . '.' . l:workflow.ext, '//', '/', 'g')
    " Set up autocommand to load template when creating new file in this workflow
    execute 'augroup struct_template_' . a:workflow_name
    execute 'autocmd!'
    execute 'autocmd BufNewFile ' . au_glob_path . ' 0r ' . template_path .
          \ " | call struct#templates#render('" . a:workflow_name . "')"
    execute 'augroup END'
  endif
endfunction
