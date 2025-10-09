function! s:validate_file_extension(workflow, filepath)
  " validate that the file extension matches
  let ext = fnamemodify(a:filepath, ':e')
  let config = g:struct_workflows[a:workflow]
  if ext !=# config.ext
    throw 'File matched workflow ' . a:workflow .
          \ ', but extension ' . ext . 
          \ ' does not match expected extension ' . config.ext
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
  let workflow = struct#utils#resolve_workflow(a:filepath)
  call s:validate_file_extension(workflow, a:filepath)
  call s:safe_edit(a:filepath)
endfunction

function! s:substitute_title_variable(title, var, values)
  let title = copy(a:title)
  let var_name = substitute(a:var, '?$', '', '')
  if has_key(a:values, var_name)
    let title = substitute(title, a:var, a:values[var_name], 'g')
  else
    " throw if variable is not optional (ends with ?)
    if reverse(a:var)[0] !=# '?'
      throw 'Missing required variable: ' . var_name
    endif
    " remove optional variable and any preceding punctuation/spaces or
    " surrounding parens
    let title = substitute(title, '\s*[-_:&+=]*\s*(\' . a:var . '\?)', '', 'g')
    let title = substitute(title, '\s*[-_:&+=]*\s*\' . a:var . '\?', '', 'g')
  endif
  return title
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

function! struct#open#generate_title(workflow, values)
  let title_format = g:struct_workflows[a:workflow].title_format
  let ext = g:struct_workflows[a:workflow].ext
  let title = copy(title_format.format)
  if title_format.has_date
    let title = strftime(title)
  endif
  let title = s:substitute_title_variables(title, title_format, a:values)
  let title = s:clean_up_title(title)
  return title . '.' . ext
endfunction

function! struct#open#open(workflow, values)
  if !has_key(g:struct_workflows, a:workflow)
    throw 'No such workflow: ' . a:workflow
  endif
  let title = struct#open#generate_title(a:workflow, a:values)
  let root = g:struct_workflows[a:workflow].root
  let filepath = simplify(fnamemodify(root . '/' . title, ':p'))
  let g:struct_context = a:values
  call struct#open#open_path(filepath)
  unlet g:struct_context
endfunction
