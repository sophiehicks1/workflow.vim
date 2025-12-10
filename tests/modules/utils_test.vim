function! TestRelativePathUtil()
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Note': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'title_format': '$title',
        \   },
        \ })

  " Test relative path utility
  let full_path = g:test_workspace . '/RepoRoot/notes/Meeting Notes.md'
  let rel_path = struct#utils#to_relative_path(full_path)
  call AssertEqual('notes/Meeting Notes.md', rel_path,
        \ "Relative path conversion is incorrect")

  " Test converting back to full path
  let converted_full_path = struct#utils#to_absolute_path(rel_path)
  call AssertEqual(full_path, converted_full_path,
        \ "Full path conversion is incorrect")

  " Test converting a path outside the workspace
  let outside_path = '/some/other/path/Other.md'
  let outside_rel_path = struct#utils#to_relative_path(outside_path)
  call AssertEqual(outside_path, outside_rel_path,
        \ "Path outside workspace should remain unchanged in relative conversion")
endfunction

function! TestWikiLinkResolution()
  " Test converting a wiki-link target to relative path
  call struct#initialize(g:test_workspace . '/RepoRoot', {
        \   'Note': {
        \     'root': 'notes/',
        \     'ext': 'md',
        \     'title_format': '$title',
        \   },
        \   'Page': {
        \     'root': './',
        \     'ext': 'html',
        \     'title_format': '$title',
        \   },
        \ })

  let wiki_link = 'notes/Meeting Notes'
  let resolved_path = struct#utils#resolve_wiki_link(wiki_link)
  call AssertEqual('notes/Meeting Notes.md', resolved_path,
        \ "Wiki-link resolution is incorrect")

  let wiki_link_page = 'Index'
  let resolved_path_page = struct#utils#resolve_wiki_link(wiki_link_page)
  call AssertEqual('Index.html', resolved_path_page,
        \ "Wiki-link resolution for page is incorrect")
endfunction
