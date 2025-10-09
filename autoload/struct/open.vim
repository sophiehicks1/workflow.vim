function! s:validate_file_extension(workflow_name, filepath)
  let expected_ext = struct#utils#get_workflow(a:workflow_name).ext
  " validate that the file extension matches
  let ext = fnamemodify(a:filepath, ':e')
  if ext !=# expected_ext
    throw 'File matched workflow ' . a:workflow_name .
          \ ', but extension ' . ext . 
          \ ' does not match expected extension ' . expected_ext
  endif
endfunction

function! s:safe_edit(filepath)
  let parent = fnamemodify(a:filepath, ':h')
  if !isdirectory(parent)
    call mkdir(parent, 'p')
  endif
  execute 'edit' fnameescape(a:filepath)
endfunction

function! struct#open#open_path(filepath)
  let workflow_name = struct#utils#resolve_workflow(a:filepath)
  call s:validate_file_extension(workflow_name, a:filepath)
  call s:safe_edit(a:filepath)
endfunction

function! s:substitute_title_variable(title, var, values)
  let l:title = copy(a:title)
  let l:var_name = substitute(a:var, '?$', '', '')
  if has_key(a:values, l:var_name)
    let l:title = substitute(l:title, a:var, a:values[l:var_name], 'g')
  else
    " throw if variable is not optional (ends with ?)
    if reverse(a:var)[0] !=# '?'
      throw 'Missing required variable: ' . l:var_name
    endif
    " remove optional variable and any preceding punctuation/spaces or
    " surrounding parens
    let l:title = substitute(l:title, '\s*[-_:&+=]*\s*(\' . a:var . '\?)', '', 'g')
    let l:title = substitute(l:title, '\s*[-_:&+=]*\s*\' . a:var . '\?', '', 'g')
  endif
  return l:title
endfunction

function! s:substitute_title_variables(title, title_format, values)
  let title = copy(a:title)
  for var in a:title_format['variables']
    let title = s:substitute_title_variable(title, var, a:values)
  endfor
  return title
endfunction

function! s:clean_up_title(title)
  " Clean up any leftover multiple spaces or leading/trailing spaces
  let title = copy(a:title)
  let title = substitute(title, '\s\+', ' ', 'g')
  let title = trim(title)
  return title
endfunction

function! struct#open#generate_title(workflow_name, values)
  let workflow = struct#utils#get_workflow(a:workflow_name)
  let title_format = workflow.title_format
  let ext = workflow.ext
  let title = copy(title_format.format)
  if title_format.has_date
    let title = strftime(title)
  endif
  let title = s:substitute_title_variables(title, title_format, a:values)
  let title = s:clean_up_title(title)
  return title . '.' . ext
endfunction

function! struct#open#open(workflow_name, values)
  let workflow = struct#utils#get_workflow(a:workflow_name)
  let title = struct#open#generate_title(a:workflow_name, a:values)
  let filepath = simplify(fnamemodify(workflow.root . '/' . title, ':p'))
  let g:struct_context = a:values
  call struct#open#open_path(filepath)
  unlet g:struct_context
endfunction
