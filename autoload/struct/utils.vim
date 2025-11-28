function s:find_matching_workflow(filepath)
  let matches = []
  for [type, config] in items(g:struct_workflows)
    let root = simplify(fnamemodify(config.root, ':p'))
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

function! struct#utils#resolve_workflow(filepath)
  let workflow = s:find_matching_workflow(a:filepath)
  " validate that a workflow was found
  if workflow ==# ''
    throw 'No matching workflow found for path: ' . a:filepath
  endif
  return workflow
endfunction

function! s:get_workflow(workflow_name)
  if !has_key(g:struct_workflows, a:workflow_name)
    throw 'No such workflow: ' . a:workflow_name
  endif
  return g:struct_workflows[a:workflow_name]
endfunction

" Public functions for path conversions

function! struct#utils#to_relative_path(full_path)
  let repo_root = simplify(fnamemodify(g:struct_repo_root, ':p'))
  let abs_full_path = simplify(fnamemodify(a:full_path, ':p'))
  if stridx(abs_full_path, repo_root) == 0
    return abs_full_path[len(repo_root) :]
  else
    " Path is outside repo root, return as is
    return a:full_path
  endif
endfunction

function! struct#utils#from_relative_path(rel_path)
  let repo_root = simplify(fnamemodify(g:struct_repo_root, ':p'))
  return simplify(fnamemodify(repo_root . '/' . a:rel_path, ':p'))
endfunction

function! struct#utils#resolve_wiki_link(wiki_link_target)
  let full_path_without_ext = struct#utils#from_relative_path(a:wiki_link_target)
  let workflow_name = struct#utils#resolve_workflow(full_path_without_ext)
  let ext = struct#utils#workflow_ext(workflow_name)
  return a:wiki_link_target . '.' . ext
endfunction

function! struct#utils#all_repo_files()
  " storing in a map, to avoid duplicates from nested workflows
  let files = {}
  for workflow_name in keys(g:struct_workflows)
    let root = struct#utils#workflow_root(workflow_name)
    let ext = struct#utils#workflow_ext(workflow_name)
    " Use globpath to find all files with the given extension under the root
    for file in globpath(root, '**/*.' . ext, 0, 1)
      let rel_path = struct#utils#to_relative_path(file)
      let files[rel_path] = 1
    endfor
  endfor
  return keys(files)
endfunction

" Public functions to query workflows
" DO NOT MODIFY WORKFLOW OBJECTS HERE - RETURN COPIES ONLY
" You can only modify workflows on startup during struct#initialize

function! struct#utils#repo_root()
  return copy(g:struct_repo_root)
endfunction

function! struct#utils#workflow_ext(workflow_name)
  let l:workflow = s:get_workflow(a:workflow_name)
  return copy(l:workflow.ext)
endfunction

function! struct#utils#workflow_title_format(workflow_name)
  let l:workflow = s:get_workflow(a:workflow_name)
  return copy(l:workflow.title_format)
endfunction

function! struct#utils#workflow_root(workflow_name)
  let l:workflow = s:get_workflow(a:workflow_name)
  return copy(l:workflow.root)
endfunction

function! struct#utils#workflow_has_template(workflow_name)
  let l:workflow = s:get_workflow(a:workflow_name)
  return has_key(l:workflow, 'template')
endfunction

function! struct#utils#workflow_template_path(workflow_name)
  let l:workflow = s:get_workflow(a:workflow_name)
  if has_key(l:workflow, 'template')
    return simplify(fnamemodify(g:struct_repo_root . '/' . l:workflow.template, ':p'))
  endif
endfunction

" FIXME: change this so that it only returns the names of the variables (so that internal structure of the variable config is hidden)
" returns: { 'variable_name': { 'optional': v:true|v:false } }
function! struct#utils#workflow_variables(workflow_name)
  let l:workflow = s:get_workflow(a:workflow_name)
  return copy(l:workflow.variables)
endfunction

function! struct#utils#is_variable_optional(workflow_name, variable_name)
  let l:workflow = s:get_workflow(a:workflow_name)
  if has_key(l:workflow.variables, a:variable_name)
    return l:workflow.variables[a:variable_name].optional
  else
    throw 'Variable ' . a:variable_name . ' not defined in workflow ' . a:workflow_name
  endif
endfunction
