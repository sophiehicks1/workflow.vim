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

