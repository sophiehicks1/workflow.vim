# COPILOT_INSTRUCTIONS.md

## Working effectively

### Dependencies and Installation

This is a Vim plugin that requires:
- Vim 7.0+ (no specific version dependencies beyond basic functionality)
- No external dependencies required for core functionality
- Optional: [vim-vinegar](https://github.com/tpope/vim-vinegar) plugin for enhanced directory navigation with the `List` commands

Installation methods:
- Manual: Copy `plugin/struct.vim` to your `~/.vim/plugin/` directory and `autoload/struct.vim` to `~/.vim/autoload/`
- Via plugin manager (Vundle, Pathogen, vim-plug, etc.): Add `Plugin 'sophiehicks1/workflow.vim'` or equivalent

### Testing and Validation

**Important**: This repository has a comprehensive automated test framework located in the `tests/` directory.

**Running Tests**:
```bash
# Run all tests
./tests/run_tests.sh

# Run tests for a specific module
./tests/run_tests.sh --module basic_workflow_working_test

# Run a specific test function
./tests/run_tests.sh --function TestBasicWorkflowCreation

# Get help
./tests/run_tests.sh --help
```

**Test Framework Structure**:
- `tests/run_tests.sh` - Main test runner script
- `tests/test_framework.vim` - Shared testing framework with assertion functions
- `tests/modules/` - Individual test modules for different functionality areas
- `tests/configs/` - Configuration files for test modules
- `tests/README.md` - Comprehensive testing documentation

**When Making Changes - You MUST**:
1. **Run the existing tests** to ensure nothing breaks: `./tests/run_tests.sh`
2. **Add new tests** for any new functionality you implement
3. **Use the shared test framework** - do NOT create module-specific assertion helpers
4. **Ensure all tests pass** before submitting changes

**Writing Tests**:
- Use the shared assertion functions from `test_framework.vim`: `Assert()`, `AssertEqual()`, `AssertExists()`, etc.
- Follow the naming convention: `Test*` for test functions
- Test modules should match configs: `my_test.vim` and `my_test_config.vim`
- Write focused, single-purpose test functions
- Test both positive and negative cases
- Include descriptive assertion messages

**Manual Validation** (in addition to automated tests):
When making changes, you should also manually test:
1. Start Vim with a test configuration file that includes the plugin
2. Define test workflows in the configuration
3. Test all workflow commands and functionality systematically
4. For isolated testing: `vim -u /path/to/test_config.vim`

**Important**: When manually sourcing files in a session, source `autoload/struct.vim` before `plugin/struct.vim` to avoid undefined function errors.

### Manual Validation Requirements

When making changes, you must manually test:

1. **Basic workflow creation and validation**:
   - Define `g:struct_workflows` with various configurations
   - Verify workflow commands are created properly
   - Test error handling for invalid workflows

2. **File operations**:
   - Test `:<Workflow> <title>` command for file creation
   - Test `:<Workflow>List` for directory navigation
   - Test `:<Workflow>Grep <query>` for searching
   - Test file opening with and without existing files

3. **Hook execution**:
   - Test `onload` and `oncreate` hooks
   - Test `:<Workflow>LoadHooks` and `:<Workflow>CreateHooks` commands
   - Verify proper variable substitution (`<FILE>`)

4. **Templates and date handling**:
   - Test template loading and variable substitution
   - Test date-based workflows (daily, weekly, monthly)
   - Test non-date workflows

5. **Mappings and autocommands**:
   - Test workflow-specific mappings (nmap, imap, etc.)
   - Test workflow-specific autocommands
   - Verify buffer-local scope

6. **Cross-platform compatibility**:
   - Test on both Unix-like systems and Windows if possible
   - Pay special attention to path handling and external commands

### Required Vim Configuration

For comprehensive testing, use a minimal vimrc that includes:

```vim
" Enable all features
set nocompatible
filetype plugin indent on
syntax enable

" Test workflow configuration
let g:struct_workflows = {
      \ "TestBlog": {
      \   'root': '~/test-workflow/blog',
      \   'date': 1,
      \   'ext': 'md',
      \   'template': '~/test-workflow/blog-template.md'
      \ },
      \ "TestNotes": {
      \   'root': '~/test-workflow/notes',
      \   'date': 0,
      \   'ext': 'txt',
      \   'onload': 'echom "Loaded: <FILE>"',
      \   'nmap': {'<leader>t': ':echo "Test mapping"<CR>'}
      \ }
      \}

" Load the plugin
call struct#initialize()
```

### Testing Commands

Essential commands to verify during testing:

```vim
" Test workflow creation
:TestBlog My First Post
:TestNotes important-note

" Test directory and search
:TestBlogList
:TestNotesGrep search term

" Test hooks
:TestBlogLoadHooks
:TestNotesCreateHooks

" Test completion (for non-dated workflows)
:TestNotes <Tab>

" Test insert path functionality (if configured)
:TestNotesInsertPath <Tab>
```

## Validation

Before submitting any changes:

1. **Automated Testing**:
   - Run the full test suite: `./tests/run_tests.sh`
   - Ensure all tests pass - fix any failures before proceeding
   - Add new tests for any functionality you add or modify
   - Use shared framework assertions, avoid creating custom test helpers

2. **Code Review Checklist**:
   - Functions are single-purpose and well-named
   - No function exceeds 20 lines
   - Minimal nesting levels (max 2)
   - Clear, readable code that explains itself
   - Proper error handling with `s:echoError()`

2. **Functionality Testing**:
   - All existing workflows continue to work  
   - New features integrate seamlessly
   - Error conditions are handled gracefully
   - Cross-platform compatibility maintained
   - **All automated tests pass**: `./tests/run_tests.sh`

3. **Documentation Updates**:
   - README.md updated if functionality changes
   - COPILOT_INSTRUCTIONS.md updated if development process changes
   - Code comments added only where necessary for complex logic

## Common tasks

### Repository Structure

```
workflow.vim/
├── README.md              # User documentation and examples
├── .github/
│   └── COPILOT_INSTRUCTIONS.md # This file - development guidelines
├── tests/                 # Automated testing framework
│   ├── run_tests.sh       # Main test runner
│   ├── test_framework.vim # Shared testing utilities
│   ├── README.md          # Testing documentation
│   ├── modules/           # Test modules
│   └── configs/           # Test configurations
├── plugin/
│   └── struct.vim         # Plugin initialization and global config
└── autoload/
    └── struct.vim         # Core functionality and public API
```

**Key architectural principles**:
- `plugin/struct.vim`: Minimal initialization, sets defaults, calls `struct#initialize()`
- `autoload/struct.vim`: Contains all functionality, lazy-loaded
- Global variable: `g:struct_workflows` - user configuration dictionary
- Naming convention: All functions use `struct#` public namespace or `s:` private scope

### Key Features and Mappings

**Core workflow features**:
1. **Dynamic command creation**: For each workflow named `X`, creates:
   - `:X <title>` - Create/open workflow file
   - `:XList` - Open workflow root directory
   - `:XGrep <query>` - Search workflow files
   - `:XLoadHooks` - Apply workflow settings to current buffer
   - `:XCreateHooks` - Apply workflow settings + creation hooks
   - `:XInsertPath <path>` - Insert workflow file path (if configured)

2. **File naming patterns**:
   - With dates: `YYYY-MM-DD-title.ext`
   - Without dates: `title.ext`
   - Title sanitization: lowercase, spaces to hyphens, special chars removed

3. **Template system**: Variable substitution with `{{{ expression }}}` syntax
   - `b:title` - Workflow title
   - `b:date` - Formatted date string

### Configuration Options

**Mandatory workflow keys**:
- `root`: Base directory for workflow files
- `ext`: File extension for workflow files

**Optional workflow keys**:
- `date`: 1 = include date in filename, 0 = no date
- `period`: 'daily', 'weekly', 'monthly' (default: 'daily')
- `mandatory-title`: 1 = require title, 0 = allow empty
- `nested`: 1 = support nested directories in titles
- `template`: Path to template file
- `onload`: Vim command to run when opening files
- `oncreate`: Vim command to run when creating new files
- `autocmd`: Dictionary of autocommands to set
- Mapping keys: `nmap`, `imap`, `nnoremap`, `inoremap`, `cmap`, `cnoremap`, `iabbrev`
- `insertPath`: Configuration for path insertion features

**Global configuration**:
- `g:workflow_template_date_format`: Date format for templates (default: '%a, %e %b %Y')

### Sample Commands for Common Operations

**Adding a new workflow**:
```vim
let g:struct_workflows['Journal'] = {
      \ 'root': '~/journal',
      \ 'date': 1,
      \ 'period': 'daily',
      \ 'ext': 'md',
      \ 'template': '~/templates/journal.md',
      \ 'onload': 'setlocal wrap linebreak',
      \ 'nmap': {'<leader>wc': ':!wc -w %<CR>'}
      \}
call struct#initialize()
```

**Creating workflow files**:
```vim
:Journal Today's thoughts
:Blog My awesome post title
:Notes meeting-with-team
```

**Debugging workflow configuration**:
```vim
:echo g:struct_workflows
:echo g:struct_workflows['WorkflowName']
```

## Troubleshooting

### Plugin Not Loading

**Symptoms**: No workflow commands available, `:Journal` shows "Not an editor command"

**Diagnosis**:
1. Check if plugin is sourced: `:scriptnames | grep struct`
2. Verify `g:struct_workflows` is defined: `:echo exists('g:struct_workflows')`
3. Check for initialization: `:echo g:did_plugin_struct`

**Solutions**:
1. Ensure plugin files are in correct directories
2. Verify `filetype plugin on` in vimrc
3. Manually source: `:source ~/.vim/plugin/struct.vim`
4. Check for syntax errors in workflow configuration

### Mappings Not Working

**Symptoms**: Buffer-local mappings not active in workflow files

**Diagnosis**:
1. Check if hooks ran: Add `echom "Hook executed"` to workflow config
2. Verify buffer-local mappings: `:map <buffer>`
3. Check workflow detection: Ensure file matches workflow pattern

**Solutions**:
1. Run hooks manually: `:WorkflowNameLoadHooks`
2. Verify mapping syntax in workflow configuration
3. Check for mapping conflicts: `:verbose map <key>`

### No Build or Compilation

**Note**: This plugin has no build system - it's pure VimScript.

**For development**:
- No compilation needed
- Reload plugin: `:source plugin/struct.vim`
- Clear autoload cache: `:unlet g:did_autoload_struct | source autoload/struct.vim`
- Test in clean Vim: `vim -u NONE -N`

## Style and structure guidelines

### Module structure

**File organization principles**:
- Keep `plugin/struct.vim` minimal - only initialization
- Put all functionality in `autoload/struct.vim` for lazy loading
- Use proper namespacing: `struct#` for public, `s:` for private functions
- Group related functions together (validation, file operations, etc.)

**Function organization pattern**:
```vim
" Helper functions first (prefixed with s:)
function! s:has_key(workflow, key)
  " Implementation
endfunction

" Core functionality functions
function! s:make_filename(workflow, title)
  " Implementation
endfunction

" Public API functions last (prefixed with struct#)
function! struct#openFile(workflowName, ...)
  " Implementation
endfunction
```

### Code style

**VimScript-specific best practices**:

1. **Variable scoping**: Always use proper scope prefixes
   - `l:` for local variables (explicit, even though it's default in functions)
   - `a:` for function arguments
   - `s:` for script-local functions and variables
   - `g:` for global variables (user configuration)
   - `b:` for buffer-local variables

2. **Function naming patterns**:
   - Private helpers: `s:descriptiveActionName()` (e.g., `s:sanitize_title()`)
   - Public API: `struct#actionObject()` (e.g., `struct#openFile()`)
   - Boolean queries: `s:has_condition()` (e.g., `s:has_date()`)
   - Validation: `s:validateNoun()` (e.g., `s:validateWorkflow()`)

3. **Error handling**: Always use consistent error reporting
   ```vim
   function! s:echoError(error)
     echohl Error
     echom a:error
     echohl None
   endfunction
   ```

4. **String handling**: Use proper quoting and escaping
   - Single quotes for literal strings
   - Double quotes when interpolation needed
   - `shellescape()` for system commands
   - `substitute()` for complex replacements

**Repository-specific style requirements**:

1. **Function length and complexity**:
   - **Maximum 15 lines preferred, absolute maximum 20 lines**
   - **Maximum one level of nested control structures** (one `if`, `for`, `while`, etc.)
   - **No more than two levels of nesting ever**
   - Factor out operations into named helper functions for clarity

2. **Code clarity principles**:
   - **Write self-documenting code** - a human should immediately understand what each function does
   - **Single responsibility** - each function does exactly one thing at one abstraction level
   - **Descriptive names** - function names should clearly state their purpose
   - **Minimal comments** - code should be so clear that comments are rarely needed

3. **Example of good function structure**:
   ```vim
   function! s:make_filename(workflow, title)
     let l:name = s:build_date_prefix(a:workflow)
     let l:sanitized_title = s:sanitize_title(a:title)
     let l:name = s:join_name_parts(l:name, l:sanitized_title)
     return l:name . '.' . a:workflow['ext']
   endfunction
   ```

4. **Example of refactoring for clarity**:
   ```vim
   " BAD: Too complex, nested, unclear intent
   function! s:process_file(workflow, locator)
     if s:has_date(a:workflow)
       let name = s:workflow_date(a:workflow)
       if len(a:locator)
         let name = name . '-' . s:sanitize_title(a:locator)
       endif
     else
       let name = s:sanitize_title(a:locator)
     endif
     return name . '.' . a:workflow['ext']
   endfunction

   " GOOD: Single purpose, clear intent, factored helpers
   function! s:make_filename(workflow, title)
     let l:date_part = s:get_date_prefix(a:workflow)
     let l:title_part = s:sanitize_title(a:title)
     return s:combine_filename_parts(l:date_part, l:title_part, a:workflow['ext'])
   endfunction

   function! s:get_date_prefix(workflow)
     return s:has_date(a:workflow) ? s:workflow_date(a:workflow) : ''
   endfunction

   function! s:combine_filename_parts(date_part, title_part, extension)
     let l:parts = filter([a:date_part, a:title_part], 'len(v:val)')
     return join(l:parts, '-') . '.' . a:extension
   endfunction
   ```

5. **Control flow guidelines**:
   - Use early returns to reduce nesting
   - Prefer positive conditions over negative when possible
   - Keep conditional blocks short and focused
   - Use helper functions instead of complex nested conditions

6. **Documentation approach**:
   - Code should be self-documenting through clear naming
   - Add comments only for complex business logic that cannot be made obvious
   - Document function parameters and return values only if not obvious from names
   - Focus on WHY, not WHAT, when commenting

**Quality assurance**:
- Before submitting, read each function aloud - if you can't immediately explain what it does, refactor it
- Ensure each function could be unit tested in isolation
- Verify that removing any function would break exactly one specific feature
- Check that function names accurately describe their complete behavior