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

" Public functions to query workflows
" DO NOT MODIFY WORKFLOW OBJECTS HERE - RETURN COPIES ONLY
" You can only modify workflows on startup during struct#initialize

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
