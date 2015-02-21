if exists("g:did_plugin_struct")
  finish
endif
let g:did_plugin_struct = 1

if ! exists("g:workflow_template_date_format")
  let g:workflow_template_date_format = '%a, %e %b %Y'
end
call struct#initialize()
