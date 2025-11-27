function! TestCsvRead()
  let file = g:test_workspace . '/CsvTestRepo/.metadata/links.csv'
  let csv_results = struct#csv#read_file(file)
  let expected_objects = [
        \ {'target': "http://example.com/page1", 'lnum': "10",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1000"},
        \ {'target': "http://example.com/page2", 'lnum': "20",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1000"},
        \ {'target': "http://example.com/page3", 'lnum': "30",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1000"},
        \ {'target': "http://example.com/page4", 'lnum': "40",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1000"},
        \ {'target': "http://example.com/page5", 'lnum': "50",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1000"},
        \ {'target': "http://example.com/page6", 'lnum': "60",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1000"},
        \ {'target': "http://example.com/page1", 'lnum': "10",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1001"},
        \ {'target': "http://example.com/page2", 'lnum': "20",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1001"},
        \ {'target': "http://example.com/page3", 'lnum': "30",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1001"},
        \ {'target': "http://example.com/page4", 'lnum': "40",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1001"},
        \ {'target': "http://example.com/page5", 'lnum': "50",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1001"},
        \ {'target': "http://example.com/page6", 'lnum': "60",
        \  '__source_file': "path/to/file.md", '__indexer': "LinkIndexer", '__timestamp': "1001"},
        \ {'target': "http://example.com/page1", 'lnum': "10",
        \  '__source_file': "path/to/file.md", '__indexer': "SecondLinkIndexer", '__timestamp': "1002"},
        \ {'target': "http://example.com/page2", 'lnum': "20",
        \  '__source_file': "path/to/file.md", '__indexer': "SecondLinkIndexer", '__timestamp': "1002"},
        \ {'target': "http://example.com/page3", 'lnum': "30",
        \  '__source_file': "path/to/file.md", '__indexer': "SecondLinkIndexer", '__timestamp': "1002"},
        \ {'target': "http://example.com/page4", 'lnum': "40",
        \  '__source_file': "path/to/file.md", '__indexer': "SecondLinkIndexer", '__timestamp': "1002"},
        \ {'target': "http://example.com/page5", 'lnum': "50",
        \ '__source_file': "path/to/file.md", '__indexer': "SecondLinkIndexer", '__timestamp': "1002"},
        \ {'target': "http://example.com/page6", 'lnum': "60",
        \  '__source_file': "path/to/file.md", '__indexer': "SecondLinkIndexer", '__timestamp': "1002"}
        \ ]
  call AssertDeepEqual(expected_objects, csv_results)

  " empty file and file with only headers should return empty array
  let empty_file = g:test_workspace . '/CsvTestRepo/.metadata/empty.csv'
  let empty_results = struct#csv#read_file(empty_file)
  call AssertDeepEqual([], empty_results)
  let headers_only_file = g:test_workspace . '/CsvTestRepo/.metadata/headers-only.csv'
  let headers_only_results = struct#csv#read_file(headers_only_file)
  call AssertDeepEqual([], headers_only_results)


  " non-existent file should throw
  let non_existent_file = g:test_workspace . '/CsvTestRepo/.metadata/non-existent-file.csv'
  call AssertThrows(function('struct#csv#read_file', [non_existent_file]), 'File not found: ' . non_existent_file)
endfunction

function! TestWriteNewCsvFile()
  let original_objects = [
        \ {'name': 'Alice', 'age': '30', 'city': 'New York'},
        \ {'name': 'Bob', 'age': '25', 'city': 'Los Angeles'},
        \ {'name': 'Charlie', 'age': '35', 'city': 'Chicago'}
        \ ]
  let output_file = g:test_workspace . '/CsvTestRepo/.metadata/new-people.csv'
  call Assert(!filereadable(output_file), 'new-people.csv should not exist before the test runs.')

  " write the data to the file and assert the file is created and the content is as expected
  call struct#csv#append_to_file(output_file, original_objects)
  call Assert(filereadable(output_file), 'new-people.csv should exist after writing data.')
  let actual_objects = struct#csv#read_file(output_file)
  call AssertDeepEqual(original_objects, actual_objects)

  " Cleanup
  call delete(output_file)
endfunction

function! TestAppendToExistingCsvFile()
  let initial_objects = [
        \ {'name': 'Alice', 'age': '30', 'city': 'New York'},
        \ {'name': 'Bob', 'age': '25', 'city': 'Los Angeles'}
        \ ]
  let append_objects = [
        \ {'name': 'Charlie', 'age': '35', 'city': 'Chicago'},
        \ {'name': 'Diana', 'age': '28', 'city': 'Denver'}
        \ ]
  let expected_objects = initial_objects + append_objects
  let output_file = g:test_workspace . '/CsvTestRepo/.metadata/existing-people.csv'

  " write the initial data to the file
  call struct#csv#append_to_file(output_file, initial_objects)
  call Assert(filereadable(output_file), 'existing-people.csv should exist after writing initial data.')
  call AssertDeepEqual(initial_objects, struct#csv#read_file(output_file))

  " append the new data to the existing file
  call struct#csv#append_to_file(output_file, append_objects)

  " read back the data and assert it matches the expected combined data
  let actual_objects = struct#csv#read_file(output_file)
  call AssertDeepEqual(expected_objects, actual_objects)

  " Cleanup
  call delete(output_file)
endfunction

function! TestMismatchedHeadersWithStrictHeadersEnabled()
  call Assert(g:struct_csv_strict_headers == 1, 'g:struct_csv_strict_headers should be enabled by default.')
  let initial_objects = [
        \ {'name': 'Alice', 'age': '30', 'city': 'New York'},
        \ {'name': 'Bob', 'age': '25', 'city': 'Los Angeles'}
        \ ]
  let append_objects = [
        \ {'name': 'Charlie', 'age': '35', 'country': 'USA'},
        \ {'name': 'Diana', 'age': '28', 'country': 'USA'}
        \ ]
  let output_file = g:test_workspace . '/CsvTestRepo/.metadata/strict-headers-people.csv'

  " write the initial data to the file
  call struct#csv#append_to_file(output_file, initial_objects)
  call Assert(filereadable(output_file), 'strict-headers-people.csv should exist after writing initial data.')
  call AssertDeepEqual(initial_objects, struct#csv#read_file(output_file))

  " appending data with mismatched headers should throw
  call AssertThrows(
        \ function('struct#csv#append_to_file', [output_file, append_objects]),
        \ 'CSV headers do not match existing file headers. Set g:struct_csv_strict_headers=0 to disable this check.'
        \ )

  " Cleanup
  call delete(output_file)
endfunction

function! TestMismatchedHeadersWithStrictHeadersDisabled()
  let default_strict_headers = g:struct_csv_strict_headers
  let g:struct_csv_strict_headers = 0
  let initial_objects = [
        \ {'name': 'Alice', 'age': '30', 'city': 'New York'},
        \ {'name': 'Bob', 'age': '25', 'city': 'Los Angeles'}
        \ ]
  let append_objects = [
        \ {'name': 'Charlie', 'age': '35', 'country': 'USA'},
        \ {'name': 'Diana', 'age': '28', 'country': 'USA'}
        \ ]
  let expected_objects = [
        \ {'name': 'Alice', 'age': '30', 'city': 'New York', 'country': ''},
        \ {'name': 'Bob', 'age': '25', 'city': 'Los Angeles', 'country': ''},
        \ {'name': 'Charlie', 'age': '35', 'country': 'USA', 'city': ''},
        \ {'name': 'Diana', 'age': '28', 'country': 'USA', 'city': ''}
        \ ]
  let output_file = g:test_workspace . '/CsvTestRepo/.metadata/non-strict-headers-people.csv'

  " write the initial data to the file
  call struct#csv#append_to_file(output_file, initial_objects)
  call Assert(filereadable(output_file), 'non-strict-headers-people.csv should exist after writing initial data.')
  call AssertDeepEqual(initial_objects, struct#csv#read_file(output_file))

  " append the new data with mismatched headers
  call struct#csv#append_to_file(output_file, append_objects)

  " read back the data and assert it matches the expected combined data
  let actual_objects = struct#csv#read_file(output_file)
  call AssertDeepEqual(expected_objects, actual_objects)

  " Cleanup
  call delete(output_file)
  let g:struct_csv_strict_headers = default_strict_headers
endfunction

function! TestReadAndWriteMessyValues()
  let messy_objects = [
        \ {'name': 'Alice, A.', 'age': '30', 'note': 'Loves "Vim" editor'},
        \ {'name': 'Bob "The Builder"', 'age': '25', 'note': 'Can we fix it? Yes, we can!'},
        \ ]
  let output_file = g:test_workspace . '/CsvTestRepo/.metadata/messy-people.csv'

  " write the messy data to the file
  call struct#csv#append_to_file(output_file, messy_objects)

  " read back the data and assert it matches the original messy data
  let actual_objects = struct#csv#read_file(output_file)
  call AssertDeepEqual(messy_objects, actual_objects)

  " Cleanup
  call delete(output_file)
endfunction
