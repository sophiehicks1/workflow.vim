"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Template rendering system
"
" Note, this code all executes within the context of the buffer being
" rendered by code inside struct#open, which sets up g:struct_context to contain
" variables for the current workflow.
"
" No variable validation is done here, because struct#open already does that.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" is_inline_content: boolean indicating if expansion_code is inline content
" (i.e. 'blah blah {{{ some code }}} blah') or expansion code on it's own lines
" for example:
"   text before expansion
"   {{{ some code }}}
"   text after expansion
" In the latter case, we should preserve newlines around the expansion when
" non-null content is returned, but remove them when null content is returned.
"
" {{{ expansion_code }}}<EOF> is treated as inline content, since there is no
" newline after the closing }}}.
function! struct#templates#execute(workflow_name, expansion_code, is_inline_content)
  let l:variable_names = keys(struct#utils#workflow_variables(a:workflow_name))
  " extract variables and pass them in as a: variables
  " skip optional variables that are not provided (aka not in g:struct_context)
  let l:variable_names = filter(l:variable_names, {_, v -> has_key(g:struct_context, v)})
  let result = ''
  try
    let func_name = 'TemplateFunc' . strftime('%s') . rand()
    let func_vars = '(' . join(l:variable_names, ', ') . ')'
    let func_lines = 'function! ' . func_name . func_vars . "\n" . a:expansion_code . "\nendfunction"
    execute func_lines
    let call_vars = map(l:variable_names, {_, v -> g:struct_context[v]})
    let result = call(func_name, call_vars)
    if result ==# v:null
      let result = ''
    elseif !a:is_inline_content
      let result = result . "\n"
    endif
  catch
    let result = 'Error executing template code: ' . v:exception
  finally
    if exists('*' . func_name)
      execute 'delfunction! ' . func_name
    endif
  endtry
  return result
endfunction

" Block expansions are found by looking for {{{ starting on a line by itself,
" and ending with }}} followed by a newline. The \ze\_. ensures that there is
" at least one character after the newline (which is excluded from the
" replacement), which prevents the \n from matching EOF. broken out into
" separate function for clarity. This is necessary otherwise the call to
" #execute(...) would replace the EOF (which isn't really a newline, but
  " matches as if it were) with an ACTUAL newline.
function! s:perform_block_expansion(workflow_name)
  " broken into pieces for clarity
  let pattern = '^' . '{{{\(' . '\_.' . '\{-}' . '\)}}}' . '\n\ze\_.'
  let replacement = '\=struct#templates#execute(a:workflow_name, submatch(1), v:false)'
  execute 'silent! %s/' . pattern . '/' . replacement . '/ge'
endfunction

function! s:perform_inline_expansion(workflow_name)
  let pattern = '{{{\(' . '\_.' . '\{-}' . '\)}}}'
  let replacement = '\=struct#templates#execute(a:workflow_name, submatch(1), v:true)'
  execute 'silent! %s/' . pattern . '/' . replacement . '/ge'
endfunction

function! s:set_modified()
  " check if any content was added to the buffer
  if line('$') > 1 || getline(1) !=# ''
    " mark buffer as modified if content was added
    setlocal modified
  else
    setlocal nomodified
  endif
endfunction

function! struct#templates#render(workflow_name)
  call s:perform_block_expansion(a:workflow_name)
  call s:perform_inline_expansion(a:workflow_name)
  call s:set_modified()
endfunction

function! struct#templates#setup_augroup(workflow_name)
  if struct#utils#workflow_has_template(a:workflow_name)
    let template_path = struct#utils#workflow_template_path(a:workflow_name)
    let root = struct#utils#workflow_root(a:workflow_name)
    let ext = struct#utils#workflow_ext(a:workflow_name)
    let au_glob_path = substitute(root . '/*' . '.' . ext, '//', '/', 'g')
    " Set up autocommand to load template when creating new file in this workflow
    execute 'augroup struct_template_' . a:workflow_name
    execute 'autocmd!'
    execute 'autocmd BufNewFile ' . au_glob_path . " call setline(1, readfile(expand('" . template_path . "')))"
          \ . " | call struct#templates#render('" . a:workflow_name . "')"
    execute 'augroup END'
  endif
endfunction
