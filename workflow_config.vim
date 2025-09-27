" This file should live in the repository root!
" Then the whole thing can be configured using `call struct#initialize('~/Notes')`, which
" - sets the root directory
" - loads root . '/schema.vim', which contains this
let g:struct_schema = {
      \   'ext': 'md',
      \   'children': {
      \     'Weekly': {
      \       'root': './weekly',
      \       'title': '%Y-W%V',
      \       'template': './templates/weekly.md'
      \     },
      \     'Monthly': {
      \       'root': './monthly',
      \       'title': '%Y-%b',
      \       'template': './templates/monthly.md'
      \     },
      \     'Journal': {
      \       'root': './journal',
      \       'title': '%Y-%m-%d $title?',
      \       'onload': 'Goyo 110'
      \     },
      \     'Search': {
      \       'root': './searches',
      \       'ext': 'cntr'
      \     },
      \     'Project': {
      \       'root': './projects',
      \       'tags': ['#project']
      \     },
      \     'Principle': {
      \       'root': './principles',
      \       'tags': ['#principle']
      \     },
      \     'Capture': {
      \       'root': './capture',
      \       'title': '%Y-%m-%d %H%M%S',
      \       'tags': ['#capture'],
      \       'template': './templates/capture.md',
      \       'children': {
      \         'Gist': {
      \           'root': './gists',
      \           'tags': ['#gist', '#Reading'],
      \           'title': '%Y-%m-%d $title'
      \         },
      \         'ProjectIdea': {
      \           'root': './ideas',
      \           'tags': ['#idea', '#project'],
      \           'title': '%Y-%m-%d $title'
      \         }
      \       }
      \     }
      \   }
      \ }

" TODO Notes on the above
" - assumes templates do not include metadata
" - tags are merged with parents, but template is replaced
" - Some of these need more thought before they're usable...

" FIXME add some validation and error handling
" FIXME this sometimes uses function args for schema/workflow, other times script state, other times global state. Fix that.

" FIXME this hard codes 'Note' as the default workflow, and '~/Notes' as the repo root
let s:root_workflow = 'Note'
let s:repo_root = '~/Notes'

function! InitializeWorkflows(schema)
  let s:workflows = {}
  " 'Note' is the root workflow, that all others inherit from
  call s:flatten_schema(s:root_workflow, a:schema, {'root': '.'})
endfunction

function! s:flatten_schema(name, schema, parent)
  let workflow = deepcopy(a:parent)
  for [key, value] in items(a:schema)
    if key !=# 'children'
      call s:add_or_merge_value(workflow, key, value)
    endif
  endfor
  let s:workflows[a:name] = workflow
  call s:process_child_schemas(a:schema, workflow)
endfunction

" associate value with key inside workflow, using the following semantics:
" - merge lists
" - nest root inside parent
" - else overwrite
function! s:add_or_merge_value(workflow, key, value)
  if type(a:value) ==# type([]) && has_key(a:workflow, a:key)
    call extend(a:workflow[a:key], a:value)
  elseif a:key ==# 'root'
    let a:workflow[a:key] = simplify(a:workflow['root'] . '/' . a:value)
  else
    let a:workflow[a:key] = a:value
  endif
endfunction

function! s:process_child_schemas(schema, parent)
  " process children last, so we can pass in inheritence
  if has_key(a:schema, 'children')
    for [n, s] in items(a:schema['children'])
      call s:flatten_schema(n, s, a:parent)
    endfor
  endif
endfunction

function! s:resolve_workflow(path)
  let matches = []
  for [type, config] in items(s:workflows)
    let root = simplify(fnamemodify(s:repo_root . '/' . config.root, ':p'))
    if stridx(fnamemodify(a:path, ':p'), root) == 0
      call add(matches, {'type': type, 'root': config.root})
    endif
  endfor
  if !len(matches)
    return s:root_workflow
  endif
  " Sort by length of root descending to get most specific match first
  call sort(matches, {a, b -> len(b.root) - len(a.root)})
  " return the type of the most specific match
  return matches[0].type
endfunction

" FIXME use this in s:flatten_schema
function! s:parse_title_config(title_config)
  " pull out any $variables from the title config
  let variables = []
  call substitute(a:title_config, '\$\(\S\+\)', '\=add(variables, submatch(0))', 'g')
  return {
        \  'format': a:title_config,
        \  'variables': map(variables, 'substitute(v:val, ''^\$'', '''', '''')')
        \}
endfunction

call InitializeWorkflows(g:struct_schema)

echom string(s:parse_title_config('$title $foo bar baz $bazinga'))
" echom string(matchall('as ad af', 'a\(.\)'))

" echom s:resolve_workflow('~/Notes/capture/gists/blah.md')
