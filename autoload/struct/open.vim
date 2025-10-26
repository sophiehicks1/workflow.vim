function! s:validate_file_extension(workflow_name, filepath)
  let expected_ext = struct#utils#workflow_ext(a:workflow_name)
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

" Public for testing, but not for general use. This is the low-level internal
" open function that all other functions call into.
function! struct#open#open_path(filepath)
  let workflow_name = struct#utils#resolve_workflow(a:filepath)
  call s:validate_file_extension(workflow_name, a:filepath)
  call s:safe_edit(a:filepath)
endfunction

function! s:substitute_title_variable(title, var_name, var_config, values)
  let l:title = copy(a:title)
  if has_key(a:values, a:var_name)
    let var_name_pattern = '\$' . a:var_name
    if a:var_config.optional ==# v:true
      let var_name_pattern = var_name_pattern . '?'
    endif
    let l:title = substitute(l:title, var_name_pattern, a:values[a:var_name], 'g')
  else
    if a:var_config.optional ==# v:false
      throw 'Missing required variable: ' . a:var_name
    endif
    " remove optional variable and any preceding punctuation/spaces or
    " surrounding parens
    let l:title = substitute(l:title, '\s*[-_:&+=]*\s*(\$' . a:var_name . '?\?)', '', 'g')
    let l:title = substitute(l:title, '\s*[-_:&+=]*\s*\$' . a:var_name . '?\?', '', 'g')
  endif
  return l:title
endfunction

function! s:substitute_title_variables(title, title_format, variables, values)
  let title = copy(a:title)
  for [var_name, var_config] in items(a:variables)
    let title = s:substitute_title_variable(title, var_name, var_config, a:values)
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
  let title_format = struct#utils#workflow_title_format(a:workflow_name)
  let variables = struct#utils#workflow_variables(a:workflow_name)
  let ext = struct#utils#workflow_ext(a:workflow_name)

  let title = copy(title_format.format)
  let values = s:apply_default_values(a:workflow_name, a:values)
  let title = s:substitute_title_variables(title, title_format, variables, values)
  if title_format.has_date
    let title = strftime(title)
  endif
  let title = s:clean_up_title(title)

  return title . '.' . ext
endfunction

function! s:normalize_value_names(values)
  let normalized = {}
  for [key, val] in items(a:values)
    let clean_key = substitute(key, '^[$]', '', 'g')
    let normalized[clean_key] = val
  endfor
  return normalized
endfunction

function! s:apply_default_values(workflow_name, values)
  let workflow_vars = struct#utils#workflow_variables(a:workflow_name)
  let values = copy(a:values)
  for [var_name, var_config] in items(workflow_vars)
    if !has_key(values, var_name) && has_key(var_config, 'default')
      let values[var_name] = var_config.default
    endif
  endfor
  return values
endfunction

function! s:open_path_with_context(filepath, workflow, values)
  let g:struct_context = s:apply_default_values(a:workflow, a:values)
  call struct#open#open_path(a:filepath)
  unlet g:struct_context
endfunction

function! struct#open#open_existing_relative_to_repo_root(relative_path)
  let repo_root = struct#utils#repo_root()
  return s:open_path_relative_to_root(a:relative_path, repo_root)
endfunction

function! struct#open#open_existing_relative_to_workflow_root(workflow_name, relative_path)
  let workflow_root = struct#utils#workflow_root(a:workflow_name)
  return s:open_path_relative_to_root(a:relative_path, workflow_root)
endfunction

function! s:open_path_relative_to_root(relative_path, root)
  let filepath = simplify(fnamemodify(a:root . '/' . a:relative_path, ':p'))
  " validate that the file is within the given root
  if stridx(filepath . '/', a:root) != 0
    throw 'File is outside root directory: ' . a:relative_path
  endif
  " validate that the file exists
  if !filereadable(filepath)
    throw 'No such file: ' . a:relative_path
  endif
  call struct#open#open_path(filepath)
endfunction

" Public function to open a file for a given workflow, generating the
" title based on the provided values. This is mostly used for creating new
" files.
function! struct#open#open(workflow_name, values)
  let root = struct#utils#workflow_root(a:workflow_name)
  let values = s:normalize_value_names(a:values)
  let title = struct#open#generate_title(a:workflow_name, values)
  let filepath = simplify(fnamemodify(root . '/' . title, ':p'))
  call s:open_path_with_context(filepath, a:workflow_name, values)
endfunction
