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
    if has_key(workflow, 'variables')
      if type(workflow.variables) !=# type({})
        throw 'Workflow "' . name . '" has invalid "variables" property: must be an dictionary mapping variable names to configs'
      endif
      for [var_name, var_config] in items(workflow.variables)
        if type(var_name) !=# type('') || match(var_name, '^\$\?[a-zA-Z_]\+?\?$') == -1
          throw 'Workflow "' . name . '" has invalid variable in "variables": ' . string(var_name)
        endif
        " validate var_config is a dictionary, with optional 'default' and
        " 'optional' keys
        if type(var_config) !=# type({})
          throw 'Workflow "' . name . '" has invalid config for variable "' . var_name . '": must be a dictionary'
        endif
        for [key, value] in items(var_config)
          if index(['default', 'optional'], key) == -1
            throw 'Workflow "' . name . '" has invalid key "' . key . '" in config for variable "' . var_name . '"'
          endif
          if key ==# 'optional' && index([0, 1, v:false, v:true], value) == -1
            throw 'Workflow "' . name . '" has invalid "optional" value for variable "' . var_name . '": must be a Boolean'
          endif
        endfor
      endfor
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

" FIXME update this comment
" Before this, workflow has a normalized title_formats with keys ('format',
" 'variables', 'has_date') and optionally has a list of non-title variables.
" After this, workflow always has a 'variables' key, which contains a variables
" object, mapping names to variable config. Variable config is {'optional':
" Boolean}
" i.e. this maps from:

" {
"   'title_format': {'format': String, 'variables': ['$variable'], 'has_date': Boolean}
"   'variables': {'other?':
"
" }
" to this

" {
"   'title_format': {'format': String, 'has_date': Boolean},
"   'variables': {'variable': {'optional': v:false}, 'other': {'optional': v:true}}
" }
" FIXME REFACTOR THIS IS HUGE
function! s:normalize_variables(workflow)
  let variables = {}
  if has_key(a:workflow, 'variables')
    let variables = deepcopy(a:workflow.variables)
    " Remove '$' from variable names in variables dictionary
    for var_name in keys(variables)
      let clean_var_name = substitute(var_name, '[$]', '', 'g')
      if clean_var_name !=# var_name
        let variables[clean_var_name] = variables[var_name]
        call remove(variables, var_name)
      endif
    endfor
  endif
  " Add title format variables to variables dictionary
  let title_var_strings = copy(a:workflow.title_format.variables)
  for var_name in title_var_strings
    let optional = reverse(var_name)[0] ==# '?'
    let clean_var_name = substitute(var_name, '[$?]', '', 'g')
    if has_key(variables, clean_var_name)
      " If variable already exists, ensure optional is consistent
      if optional 
            \ && has_key(variables[clean_var_name], 'optional')
            \ && (variables[clean_var_name].optional ==# v:false || variables[clean_var_name].optional ==# 0)
        throw 'Conflict in variable configuration for "' . clean_var_name
              \ . '" between title_format and variables config'
      elseif !optional 
            \ && has_key(variables[clean_var_name], 'optional')
            \ && (variables[clean_var_name].optional ==# v:true || variables[clean_var_name].optional ==# 1)
        throw 'Conflict in variable configuration for "' . clean_var_name
              \ . '" between title_format and variables config'
      endif
      let variables[clean_var_name] = extend(variables[clean_var_name], { 'optional': optional })
    else
      let variables[clean_var_name] = { 'optional': optional }
    endif
  endfor
  let l:workflow = deepcopy(a:workflow)
  let l:workflow.variables = variables
  unlet l:workflow.title_format.variables
  return l:workflow
endfunction

function! s:normalize_workflow(workflow)
  let l:workflow = deepcopy(a:workflow)
  if !has_key(l:workflow, 'title_format')
    let l:workflow.title_format = '$title'
  endif
  let l:workflow.title_format = struct#init#parse_title_format(l:workflow.title_format)
  let l:workflow = s:normalize_variables(l:workflow)
  return l:workflow
endfunction

function! s:normalize_config(root, workflows)
  let l:workflows = deepcopy(a:workflows)
  for [name, workflow] in items(a:workflows)
    " Update root to be absolute path
    let workflow.root = simplify(fnamemodify(a:root . '/' . workflow.root, ':p'))
    let l:workflows[name] = s:normalize_workflow(workflow)
  endfor
  return l:workflows
endfunction

function! struct#init#initialize(root, workflows)
  let g:struct_repo_root = expand(a:root)
  call s:validate_repository_root(g:struct_repo_root)
  call s:validate_workflow_config(a:workflows)
  let g:struct_workflows = s:normalize_config(g:struct_repo_root, a:workflows)

  for [name, workflow] in items(g:struct_workflows)
    call struct#templates#setup_augroup(name)
    call struct#commands#initialize_workflow_commands(name)
  endfor
endfunction
