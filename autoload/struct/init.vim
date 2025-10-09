function! s:validate_workflow_config(workflows)
  for [name, workflow] in items(a:workflows)
    if !has_key(workflow, 'root')
      throw 'Workflow "' . name . '" is missing required "root" property'
    endif
    if !has_key(workflow, 'ext')
      throw 'Workflow "' . name . '" is missing required "ext" property'
    endif
    " validate template exists and readable if provided
    if has_key(workflow, 'template')
      let template_path = simplify(fnamemodify(g:struct_repo_root . '/' . workflow.template, ':p'))
      if !filereadable(template_path)
        throw 'Template file not found: ' . template_path
      endif
    endif
  endfor
endfunction

function! s:is_absolute_path(path)
  " standardize trailing slash for comparison
  let l:path = substitute(a:path, '/\+$', '', '') . '/'
  return fnamemodify(l:path, ':p') == l:path
endfunction

function! s:validate_repository_root(root)
  if !s:is_absolute_path(a:root)
    throw 'Repository root must be an absolute path: ' . a:root . ' (got ' . fnamemodify(a:root, ':p') . ')'
  endif
  if !isdirectory(a:root)
    if filereadable(a:root) || filewritable(a:root)
      throw 'Repository root must be a directory: ' . a:root
    else
      " create the directory if it does not exist
      call mkdir(a:root, 'p')
    endif
  endif
endfunction

function s:validate_title_format(title_format)
  if type(a:title_format) !=# type('')
    throw 'Title format must be a string'
  endif
  " Validate title_format only consist of [a-zA-z0-9-_%:()&+=?] characters
  let invalid_chars_regex = '[^$a-zA-Z0-9\-_%:()&+=? ]'
  if match(a:title_format, invalid_chars_regex) != -1
    throw 'Title format contains invalid characters: ' . matchstr(a:title_format, invalid_chars_regex)
  endif
endfunction

" Public for testing
function! struct#init#parse_title_format(title_format)
  call s:validate_title_format(a:title_format)
  " pull out any $variables from the title format
  let variables = []
  call substitute(a:title_format, '\$\([a-zA-Z_?]\+\)', '\=add(variables, submatch(0))', 'g')
  " check for date components (e.g. %Y, %m, %d, etc. see `man date` for full list) 
  let title_has_date = match(a:title_format, '%\S') != -1
  return {
        \  'format': a:title_format,
        \  'variables': variables,
        \  'has_date': title_has_date,
        \ }
endfunction

function! s:normalize_workflow(workflow)
  let l:workflow = deepcopy(a:workflow)
  if !has_key(l:workflow, 'title_format')
    let l:workflow.title_format = '$title'
  endif
  let l:workflow.title_format = struct#init#parse_title_format(l:workflow.title_format)
  return l:workflow
endfunction

function! s:normalize_config(root, workflows)
  let l:workflows = deepcopy(a:workflows)
  " Update root to be absolute path
  for [name, workflow] in items(a:workflows)
    let workflow.root = simplify(fnamemodify(a:root . '/' . workflow.root, ':p'))
    let l:workflows[name] = s:normalize_workflow(workflow)
  endfor
  return l:workflows
endfunction

function! struct#init#initialize(root, workflows)
  let g:struct_repo_root = a:root
  call s:validate_repository_root(a:root)
  call s:validate_workflow_config(a:workflows)
  let g:struct_workflows = s:normalize_config(a:root, a:workflows)
  for [name, workflow] in items(g:struct_workflows)
    call struct#templates#apply(name, workflow)
  endfor
endfunction
