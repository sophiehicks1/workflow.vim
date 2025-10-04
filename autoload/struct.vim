function! s:validate_workflow_config(workflows)
  for [name, workflow] in items(a:workflows)
    if !has_key(workflow, 'root')
      throw 'Workflow "' . name . '" is missing required "root" property'
    endif
    if !has_key(workflow, 'ext')
      throw 'Workflow "' . name . '" is missing required "ext" property'
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

function! s:normalize_config(root, workflows)
  let l:workflows = deepcopy(a:workflows)
  " Update root to be absolute path
  for [name, workflow] in items(a:workflows)
    let workflow.root = simplify(fnamemodify(a:root . '/' . workflow.root, ':p'))
    let l:workflows[name] = workflow
  endfor
  return l:workflows
endfunction

function! struct#initialize(root, workflows)
  let g:struct_repo_root = a:root
  call s:validate_repository_root(a:root)
  call s:validate_workflow_config(a:workflows)
  let g:struct_workflows = s:normalize_config(a:root, a:workflows)
endfunction

function s:find_matching_workflow(filepath)
  let matches = []
  for [type, config] in items(g:struct_workflows)
    echom type
    echom config.root
    let root = simplify(fnamemodify(config.root, ':p'))
    echom root
    if stridx(fnamemodify(a:filepath, ':p'), root) == 0
      call add(matches, {'type': type, 'root': config.root})
    endif
  endfor
  if !len(matches)
    return ''
  endif
  " Sort by length of root descending to get most specific match first
  call sort(matches, {a, b -> len(b.root) - len(a.root)})
  " return the type of the most specific match
  return matches[0].type
endfunction

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

function! s:ensure_parent_directories(filepath)
  let parent = fnamemodify(a:filepath, ':h')
  if !isdirectory(parent)
    call mkdir(parent, 'p')
  endif
endfunction

function! struct#resolve_workflow(filepath)
  let workflow = s:find_matching_workflow(a:filepath)
  " validate that a workflow was found
  if workflow ==# ''
    throw 'No matching workflow found for path: ' . a:filepath
  endif
  call s:validate_file_extension(workflow, a:filepath)
  return workflow
endfunction

function! struct#open_path(filepath)
  let workflow = struct#resolve_workflow(a:filepath)
  call s:ensure_parent_directories(a:filepath)
  execute 'edit' fnameescape(a:filepath)
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

function! struct#parse_title_format(title_format)
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

function! s:substitute_title_variables(title, parsed, values)
  let title = copy(a:title)
  for var in a:parsed['variables']
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

function! struct#generate_title(workflow, values)
  let title_format = g:struct_workflows[a:workflow].title_format
  let ext = g:struct_workflows[a:workflow].ext
  let parsed = struct#parse_title_format(title_format)
  let title = copy(parsed.format)
  if parsed.has_date
    let title = strftime(title)
  endif
  let title = s:substitute_title_variables(title, parsed, a:values)
  let title = s:clean_up_title(title)
  return title . '.' . ext
endfunction
