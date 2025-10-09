function! struct#initialize(root, workflows)
  call struct#init#initialize(a:root, a:workflows)
endfunction

function! struct#open(workflow, values)
  call struct#open#open(a:workflow, a:values)
endfunction
