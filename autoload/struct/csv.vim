" Functions for reading CSV files
function! s:parse_csv_into_lists(lines) abort
  let rows = []
  for line in a:lines
    let values = []
    let current_value = ''
    let in_quotes = 0
    let i = 0
    while i < len(line)
      let char = line[i]
      if char == '"'
        if in_quotes && i + 1 < len(line) && line[i + 1] == '"'
          " Escaped quote
          let current_value .= '"'
          let i += 1
        else
          let in_quotes = !in_quotes
        endif
      elseif char == ',' && !in_quotes
        call add(values, current_value)
        let current_value = ''
      else
        let current_value .= char
      endif
      let i += 1
    endwhile
    call add(values, current_value)
    call add(rows, values)
  endfor
  return rows
endfunction

function! s:parse_csv_lines(lines) abort
  let rows = s:parse_csv_into_lists(a:lines)
  if empty(rows)
    return []
  endif
  let headers = rows[0]
  let dict_rows = []
  for row in rows[1:]
    let dict_row = {}
    for i in range(len(headers))
      let header = headers[i]
      let value = i < len(row) ? row[i] : ''
      let dict_row[header] = value
    endfor
    call add(dict_rows, dict_row)
  endfor
  return dict_rows
endfunction

function! struct#csv#read_file(file_path) abort
  if !filereadable(a:file_path)
    throw 'File not found: ' . a:file_path
  endif
  let lines = readfile(a:file_path)
  return s:parse_csv_lines(lines)
endfunction

function! s:format_csv_line(values) abort
  let csv_values = []
  for value in a:values
    let escaped_value = '"' . substitute(value, '"', '""', 'g') . '"'
    call add(csv_values, escaped_value)
  endfor
  return join(csv_values, ',')
endfunction

" Functions for writing CSV files
function! s:get_existing_headers_from_file(file_path) abort
  if filereadable(a:file_path)
    let lines = readfile(a:file_path)
    if !empty(lines)
      return s:parse_csv_into_lists([lines[0]])[0]
    endif
  endif
  return []
endfunction

function! s:get_headers_from_dict_rows(dict_rows) abort
  return keys(a:dict_rows[0])
endfunction

function! s:map_values_to_headers(headers, row) abort
  let values = []
  for header in a:headers
    call add(values, a:row[header])
  endfor
  return values
endfunction

function! s:safe_writefile(lines, file_path, mode) abort
  if !isdirectory(fnamemodify(a:file_path, ':h'))
    call mkdir(fnamemodify(a:file_path, ':h'), 'p')
  endif
  call writefile(a:lines, a:file_path, a:mode)
endfunction

function! s:simple_csv_write(file_path, headers, dict_rows) abort
  call s:safe_writefile([s:format_csv_line(a:headers)], a:file_path, 's')
  for row in a:dict_rows
    let row_values = s:map_values_to_headers(a:headers, row)
    call s:safe_writefile([s:format_csv_line(row_values)], a:file_path, 'a')
  endfor
endfunction

function! s:simple_csv_append(file_path, headers, dict_rows) abort
  for row in a:dict_rows
    let row_values = s:map_values_to_headers(a:headers, row)
    call s:safe_writefile([s:format_csv_line(row_values)], a:file_path, 'a')
  endfor
endfunction

function! s:merge_headers(existing_rows, new_rows) abort
  let all_headers = {}
  for row in a:existing_rows + a:new_rows
    for key in keys(row)
      let all_headers[key] = 1
    endfor
  endfor
  return keys(all_headers)
endfunction

function! s:merge_data(existing_data, merged_headers, dict_rows) abort
  let merged_rows = a:existing_data + a:dict_rows
  for row in merged_rows
    for header in a:merged_headers
      if !has_key(row, header)
        let row[header] = ''
      endif
    endfor
  endfor
  return merged_rows
endfunction

function! s:merging_csv_write(file_path, dict_rows) abort
  echohl WarningMsg
  echom 'CSV headers do not match existing file headers. Merging data with unified headers.'
  echohl None
  let existing_data = struct#csv#read_file(a:file_path)
  let merged_headers = s:merge_headers(existing_data, a:dict_rows)
  let merged_data = s:merge_data(existing_data, merged_headers, a:dict_rows)
  call s:simple_csv_write(a:file_path, merged_headers, merged_data)
endfunction

function! struct#csv#append_to_file(file_path, dict_rows) abort
  let existing_headers = s:get_existing_headers_from_file(a:file_path)
  let data_headers = s:get_headers_from_dict_rows(a:dict_rows)
  if empty(existing_headers)
    call s:simple_csv_write(a:file_path, data_headers, a:dict_rows)
  elseif existing_headers == data_headers
    call s:simple_csv_append(a:file_path, existing_headers, a:dict_rows)
  else
    if exists('g:struct_csv_strict_headers') && g:struct_csv_strict_headers
      throw 'CSV headers do not match existing file headers. ' .
            \ 'Set g:struct_csv_strict_headers=0 to disable this check.'
    else
      call s:merging_csv_write(a:file_path, a:dict_rows)
    endif
  endif
endfunction

function! struct#csv#overwrite_file(file_path, dict_rows) abort
  call struct#metadata#log_debug('Overwriting CSV file: ' . a:file_path . 
        \ ' with ' . len(a:dict_rows) . ' rows.')
  if empty(a:dict_rows)
    " No data to write, create an empty file
    call s:safe_writefile([], a:file_path, 's')
    return
  endif
  let headers = s:get_headers_from_dict_rows(a:dict_rows)
  call s:simple_csv_write(a:file_path, headers, a:dict_rows)
endfunction
