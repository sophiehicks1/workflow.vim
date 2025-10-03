# workflow.vim Test Framework

This directory contains a comprehensive automated testing framework for the workflow.vim plugin. The framework provides a complete testing solution with assertion functions, test isolation, detailed reporting, and flexible test execution.

## Quick Start

To run all tests from the repository root:

```bash
./tests/run_tests.sh
```

To run tests for a specific module:

```bash  
./tests/run_tests.sh --module basic_workflow_test
```

To run a specific test function:

```bash
./tests/run_tests.sh --function TestBasicWorkflowCreation
```

## Framework Architecture

### Directory Structure

```
tests/
├── run_tests.sh                    # Main test runner script
├── test_framework.vim              # Core testing framework
├── README.md                       # This documentation
├── modules/                        # Test modules directory
│   ├── basic_workflow_test.vim     # Basic workflow functionality tests
│   ├── template_test.vim           # Template processing tests
│   ├── hooks_test.vim              # Hook execution tests
│   ├── validation_test.vim         # Validation and error handling tests
│   └── meta/                       # Meta-tests (test framework validation)
│       ├── failure_demo_test.vim   # Demonstrates failure reporting
│       ├── simple_test.vim         # Basic framework validation
│       └── ultra_simple_test.vim   # Minimal framework validation
└── configs/                        # Test configuration files
    ├── basic_workflow_test_config.vim
    ├── template_test_config.vim
    ├── hooks_test_config.vim
    ├── validation_test_config.vim
    └── meta/                       # Meta-test configurations
        ├── failure_demo_test_config.vim
        ├── simple_test_config.vim
        └── ultra_simple_test_config.vim
```

### Core Components

1. **Test Runner (`run_tests.sh`)**: Main entry point that orchestrates test execution
2. **Test Framework (`test_framework.vim`)**: Provides assertion functions and test management
3. **Test Modules**: Individual test files containing test functions
4. **Test Configs**: Configuration files that set up test environments

### Meta-Tests

Meta-tests are tests that validate the test framework itself rather than the workflow.vim plugin. They are located in the `tests/modules/meta/` subdirectory and are automatically excluded from normal test runs.

**Purpose:**
- Verify that test framework assertions work correctly
- Demonstrate failure reporting behavior
- Validate test discovery and execution mechanisms

**Running Meta-Tests:**
- Use `--validate-test-framework` flag to include meta-tests in test runs
- Use `--module <meta_test_name>` to run a specific meta-test module
- Meta-tests are excluded by default to focus on plugin functionality tests

**Available Meta-Test Modules:**
- `failure_demo_test.vim` - Demonstrates how test failures are reported (includes intentional failures)
- `simple_test.vim` - Basic framework validation tests
- `ultra_simple_test.vim` - Minimal framework validation tests

## Test Runner Features

The test runner (`run_tests.sh`) provides:

- **Root Directory Validation**: Ensures tests run from the repository root
- **Temporary Directory Management**: Creates isolated test environments
- **Module Filtering**: Run specific test modules with `--module`
- **Function Filtering**: Run specific test functions with `--function`
- **Meta-Test Exclusion**: Automatically excludes meta-tests (test framework validation tests) unless `--validate-test-framework` is specified
- **Comprehensive Reporting**: Shows total tests run, passed, and failed
- **Detailed Error Reporting**: Provides specific failure information
- **Exit Code Support**: Returns appropriate exit codes for CI/CD integration

### Usage Examples

```bash
# Run all tests (excludes meta-tests)
./tests/run_tests.sh

# Run all tests including meta-tests (test framework validation)
./tests/run_tests.sh --validate-test-framework

# Run only basic workflow tests
./tests/run_tests.sh --module basic_workflow_test

# Run only template-related tests  
./tests/run_tests.sh --module template_test

# Run a specific test function across all modules
./tests/run_tests.sh --function TestBasicWorkflowCreation

# Combine filters (run specific function in specific module)
./tests/run_tests.sh --module hooks_test --function TestOnloadHook

# Run a meta-test module
./tests/run_tests.sh --module failure_demo_test

# Show help
./tests/run_tests.sh --help
```

## Test Framework API

The test framework provides a comprehensive set of assertion functions and utilities:

### Assertion Functions

#### Basic Assertions
- `Assert(condition, message)` - Assert that a condition is true
- `AssertEqual(expected, actual, [message])` - Assert values are equal
- `AssertNotEqual(expected, actual, [message])` - Assert values are not equal
- `AssertMatches(pattern, actual, [message])` - Assert string matches pattern

#### File System Assertions  
- `AssertFileExists(filepath, [message])` - Assert file exists
- `AssertFileNotExists(filepath, [message])` - Assert file doesn't exist
- `AssertDirExists(dirpath, [message])` - Assert directory exists

#### Vim-Specific Assertions
- `AssertExists(varname, [message])` - Assert variable exists
- `AssertThrows(command, pattern, [message])` - Assert command throws expected exception

### Test Lifecycle Functions

- `TestSetup()` - Called before each test function
- `TestTeardown()` - Called after each test function
- `TestFrameworkInit()` - Initialize test framework
- `TestFrameworkCleanup()` - Clean up test framework

### Helper Functions

- `CreateTestWorkflow(name, config)` - Create a test workflow configuration
- `CreateTestFile(filepath, content)` - Create a test file with content
- `ReadTestFile(filepath)` - Read file content as string

### Test Environment Variables

- `g:test_module_name` - Current test module name
- `g:test_temp_dir` - Temporary directory for testing
- `g:test_workspace` - Module-specific test workspace
- `g:current_test_dir` - Current test-specific directory
- `g:test_function_filter` - Function filter from command line

## Writing Tests

### Test Module Structure

Test modules follow a specific naming convention and structure:

```vim
" module_name_test.vim - Description of test module
" Tests specific functionality area

" Test function - must start with 'Test'
function! TestSomeFeature()
  " Setup test data
  call CreateTestWorkflow('TestName', {
        \ 'root': g:test_workspace . '/test_dir',
        \ 'ext': 'txt',
        \ 'date': 1
        \ })
  
  " Test assertions
  call Assert(has_key(g:struct_workflows, 'TestName'), 'Workflow should exist')
  call AssertEqual('txt', g:struct_workflows['TestName']['ext'], 'Extension should be txt')
  
  " Verify file system state
  call AssertDirExists(g:test_workspace . '/test_dir', 'Directory should exist')
endfunction

" Another test function
function! TestAnotherFeature()
  " Each test function is isolated and independent
  " Test framework handles setup/teardown automatically
endfunction
```

### Configuration Files

Each test module should have a corresponding configuration file:

```vim
" module_name_test_config.vim
" Configuration for module_name_test.vim

" Clean slate for testing
if exists("g:struct_workflows")
  unlet g:struct_workflows
endif

" Set up test-specific variables
let g:test_specific_setting = 'value'

" Define helper functions if needed
function! ModuleSpecificHelper()
  " Helper function for this module's tests
endfunction
```

### Naming Conventions

- **Test Modules**: `*_test.vim` (e.g., `basic_workflow_test.vim`)
- **Config Files**: `*_test_config.vim` (e.g., `basic_workflow_test_config.vim`)
- **Test Functions**: `Test*` (e.g., `TestBasicWorkflowCreation`)
- **Workflows in Tests**: `Test*` prefix to avoid conflicts

## Best Practices

### Test Independence
- Each test function should be completely independent
- Use `TestSetup()` and `TestTeardown()` for per-test isolation
- Don't rely on state from previous tests
- Clean up any global variables or configurations

### Test Data Management
- Use `g:test_workspace` for creating test files and directories
- Create unique directory names for each test
- Use `CreateTestFile()` for creating test files
- All test data is automatically cleaned up

### Assertion Practices
- Use descriptive assertion messages
- Test both positive and negative cases
- Use the most specific assertion function available
- Group related assertions together

### Error Testing
- Use `AssertThrows()` to test error conditions
- Test edge cases and boundary conditions
- Verify error messages are meaningful
- Test recovery from errors

### Example Test Function
```vim
function! TestWorkflowWithTemplate()
  " Create test template file
  let template_path = g:test_workspace . '/test_template.md'
  call CreateTestFile(template_path, "# {{{ b:title }}}\n\nContent...")
  
  " Create workflow with template
  call CreateTestWorkflow('TemplateTest', {
        \ 'root': g:test_workspace . '/templated_files',
        \ 'ext': 'md',
        \ 'template': template_path,
        \ 'date': 1,
        \ 'mandatory-title': 1
        \ })
  
  " Verify workflow creation
  call Assert(has_key(g:struct_workflows, 'TemplateTest'), 'Workflow should exist')
  call AssertEqual(template_path, g:struct_workflows['TemplateTest']['template'], 'Template should be set')
  
  " Verify template file
  call AssertFileExists(template_path, 'Template file should exist')
  
  " Verify content
  let content = ReadTestFile(template_path)
  call AssertMatches('{{{ b:title }}}', content, 'Template should contain title variable')
endfunction
```

## Test Coverage

The current test suite provides comprehensive coverage of:

### Core Functionality
- Workflow creation and initialization
- Configuration validation
- Directory and file management
- Command generation

### Template System
- Template loading and processing
- Variable substitution (`{{{ b:title }}}`, `{{{ b:date }}}`)
- Multiple template formats
- Error handling for missing templates

### Hook System
- `onload` and `oncreate` hooks
- File path substitution in hooks
- Mapping definitions (nmap, imap, cmap, etc.)
- Abbreviations (iabbrev)
- Autocmd definitions

### Validation and Error Handling
- Required field validation
- Path resolution and directory creation
- Error recovery and reporting
- Edge cases and boundary conditions

## Extending the Test Suite

### Adding New Test Modules

1. Create test module file: `tests/modules/new_feature_test.vim`
2. Create config file: `tests/configs/new_feature_test_config.vim`
3. Write test functions following naming conventions
4. Test your new module: `./tests/run_tests.sh --module new_feature_test`

### Adding Test Functions to Existing Modules

1. Add new `TestFeatureName()` function to appropriate module
2. Follow existing patterns and best practices
3. Test the specific function: `./tests/run_tests.sh --function TestFeatureName`

### Adding New Meta-Test Modules

Meta-tests validate the test framework itself. To add a new meta-test:

1. Create test module file: `tests/modules/meta/new_meta_test.vim`
2. Create config file: `tests/configs/meta/new_meta_test_config.vim`
3. Write test functions that validate framework behavior
4. Test your new meta-test: `./tests/run_tests.sh --module new_meta_test`

**Note:** Meta-tests are automatically excluded from regular test runs. Place test modules in the `tests/modules/meta/` subdirectory to have them treated as meta-tests.

### Test Organization Tips

- Group related functionality in the same module
- Keep test functions focused and concise
- Use descriptive names that explain what's being tested
- Document complex test scenarios with comments
- Place framework validation tests in `tests/modules/meta/`
- Place plugin functionality tests in `tests/modules/`

## Continuous Integration

The test framework is designed for CI/CD integration:

- Returns exit code 0 on success, 1 on failure
- Provides structured output for parsing
- Supports filtering for running subset of tests
- Handles cleanup automatically

Example CI usage:
```bash
# In CI pipeline
./tests/run_tests.sh
if [ $? -ne 0 ]; then
    echo "Tests failed!"
    exit 1
fi
```

## Troubleshooting

### Common Issues

**Tests not found**: Ensure you're running from repository root and test files follow naming conventions.

**Permission errors**: Make sure `run_tests.sh` is executable: `chmod +x tests/run_tests.sh`

**Vim not found**: Ensure vim is installed and available in PATH.

**Template errors**: Check that template files exist and have correct permissions.

### Debug Mode

For debugging test issues, you can run vim manually with the same parameters as the test runner:

```bash
vim -e -s -u NONE --noplugin \
  -c 'let g:test_module_name="basic_workflow_test"' \
  -c 'let g:test_temp_dir="/tmp/test_dir"' \
  -c 'source plugin/struct.vim' \
  -c 'source autoload/struct.vim' \
  -c 'source tests/test_framework.vim' \
  -c 'source tests/modules/basic_workflow_test.vim' \
  -c 'call RunTestModule()' \
  -c 'qall!'
```

## Contributing

When contributing new tests or test framework improvements:

1. Follow existing naming conventions
2. Ensure tests are independent and isolated
3. Include both positive and negative test cases
4. Update documentation for new features
5. Test your changes with the full test suite

The test framework is designed to be maintainable, extensible, and reliable. It provides a solid foundation for ensuring the workflow.vim plugin works correctly across different configurations and use cases.