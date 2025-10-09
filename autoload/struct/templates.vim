function! struct#templates#execute(workflow_name, lines)
  let result = ''
  try
    let func_name = 'TemplateFunc' . strftime('%s') . rand()
    let func_lines = 'function! ' . func_name . "()\n" . a:lines . "\nendfunction"
    execute func_lines
    let result = call(func_name, [])
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

function! struct#templates#apply(name, workflow)
  if has_key(a:workflow, 'template')
    let template_path = simplify(fnamemodify(g:struct_repo_root . '/' . a:workflow.template, ':p'))
    let au_glob_path = substitute(a:workflow.root . '/*' . '.' . a:workflow.ext, '//', '/', 'g')
    " Set up autocommand to load template when creating new file in this workflow
    execute 'augroup struct_template_' . a:name
    execute 'autocmd!'
    execute 'autocmd BufNewFile ' . au_glob_path .
          \ ' 0r ' . template_path .
          \ " | call struct#templates#render('" . a:name . "')"
    execute 'augroup END'
  endif
endfunction
