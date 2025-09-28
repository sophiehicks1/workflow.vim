#!/bin/bash

# Test runner for workflow.vim automated tests
# Usage: ./tests/run_tests.sh [--module MODULE] [--function FUNCTION]

set -e

# Validate we're running from repo root
if [ ! -f "plugin/struct.vim" ] || [ ! -f "autoload/struct.vim" ]; then
    echo "Error: Tests must be run from the repository root directory"
    echo "Expected files plugin/struct.vim and autoload/struct.vim not found"
    exit 1
fi

# Parse command line arguments
MODULE_FILTER=""
FUNCTION_FILTER=""
VALIDATE_TEST_FRAMEWORK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --module)
            MODULE_FILTER="$2"
            shift 2
            ;;
        --function)
            FUNCTION_FILTER="$2"
            shift 2
            ;;
        --validate-test-framework)
            VALIDATE_TEST_FRAMEWORK=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--module MODULE] [--function FUNCTION] [--validate-test-framework]"
            echo ""
            echo "Options:"
            echo "  --module MODULE               Run only tests from the specified module"
            echo "  --function FUNCTION           Run only the specified test function"
            echo "  --validate-test-framework     Include framework validation tests"
            echo "  -h, --help                   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Create temporary directory for testing
TEST_TEMP_DIR=$(mktemp -d -t workflow_vim_tests.XXXXXX)
export TEST_TEMP_DIR
echo "Using temporary directory: $TEST_TEMP_DIR"

# Cleanup function
cleanup() {
    echo "Cleaning up temporary directory: $TEST_TEMP_DIR"
    rm -rf "$TEST_TEMP_DIR"
}
trap cleanup EXIT

# Initialize test framework variables
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Find test modules
TEST_MODULES_DIR="tests/modules"
if [ ! -d "$TEST_MODULES_DIR" ]; then
    echo "Error: Test modules directory '$TEST_MODULES_DIR' not found"
    exit 1
fi

# Get list of test modules
if [ -n "$MODULE_FILTER" ]; then
    TEST_MODULE_FILES=$(find "$TEST_MODULES_DIR" -name "*${MODULE_FILTER}*.vim" | sort)
else
    TEST_MODULE_FILES=$(find "$TEST_MODULES_DIR" -name "*.vim" | sort)
    
    # Exclude framework test modules unless --validate-test-framework is specified
    if [ "$VALIDATE_TEST_FRAMEWORK" = false ]; then
        # Framework test modules to exclude by default
        FRAMEWORK_MODULES=(
            "failure_demo_test.vim"
            "simple_test.vim"
            "ultra_simple_test.vim"
        )
        
        FILTERED_FILES=""
        for module_file in $TEST_MODULE_FILES; do
            module_name=$(basename "$module_file")
            exclude=false
            
            # Check framework modules
            for framework_module in "${FRAMEWORK_MODULES[@]}"; do
                if [[ "$module_name" == "$framework_module" ]]; then
                    exclude=true
                    break
                fi
            done
            
            if [ "$exclude" = false ]; then
                FILTERED_FILES="$FILTERED_FILES $module_file"
            fi
        done
        TEST_MODULE_FILES=$FILTERED_FILES
    fi
fi

if [ -z "$TEST_MODULE_FILES" ]; then
    echo "No test modules found matching filter"
    exit 1
fi

echo "Running workflow.vim automated tests..."
echo "======================================"

# Run each test module
for module_file in $TEST_MODULE_FILES; do
    module_name=$(basename "$module_file" .vim)
    
    echo ""
    echo "Running module: $module_name"
    echo "------------------------------"
    
    # Find corresponding config file
    config_file="tests/configs/${module_name}_config.vim"
    if [ ! -f "$config_file" ]; then
        echo "WARNING: No config file found for module $module_name (expected: $config_file)"
        config_file=""
    fi
    
    # Run the test module with vim
    vim_cmd="vim -e -s -u NONE --noplugin"
    vim_cmd="$vim_cmd -c 'let g:test_module_name=\"$module_name\"'"
    vim_cmd="$vim_cmd -c 'let g:test_temp_dir=\"$TEST_TEMP_DIR\"'"
    vim_cmd="$vim_cmd -c 'let g:test_function_filter=\"$FUNCTION_FILTER\"'"
    
    # Source the autoload file to make plugin functions available for testing
    vim_cmd="$vim_cmd -c 'source autoload/struct.vim'"
    
    # Source config file if it exists
    if [ -n "$config_file" ]; then
        vim_cmd="$vim_cmd -c 'source $config_file'"
    fi
    
    # Source test framework and run tests
    vim_cmd="$vim_cmd -c 'source tests/test_framework.vim'"
    vim_cmd="$vim_cmd -c 'source $module_file'"
    vim_cmd="$vim_cmd -c 'call RunTestModule()'"
    vim_cmd="$vim_cmd -c 'qall!'"
    
    # Execute vim and capture output
    output=$(eval $vim_cmd 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then        
        # Try to read results from file first, then fallback to parsing output
        result_file="$TEST_TEMP_DIR/test_results.txt"
        if [ -f "$result_file" ]; then
            module_total=$(grep "^TESTS_RUN:" "$result_file" | cut -d: -f2 | tr -d ' ')
            module_passed=$(grep "^TESTS_PASSED:" "$result_file" | cut -d: -f2 | tr -d ' ')
            module_failed=$(grep "^TESTS_FAILED:" "$result_file" | cut -d: -f2 | tr -d ' ')
            rm -f "$result_file"  # Clean up
        else
            # Fallback to parsing output
            module_total=$(echo "$output" | grep "^TESTS_RUN:" | cut -d: -f2 | tr -d ' ')
            module_passed=$(echo "$output" | grep "^TESTS_PASSED:" | cut -d: -f2 | tr -d ' ')
            module_failed=$(echo "$output" | grep "^TESTS_FAILED:" | cut -d: -f2 | tr -d ' ')
        fi
        
        if [ -n "$module_total" ] && [ -n "$module_passed" ] && [ -n "$module_failed" ]; then
            TOTAL_TESTS=$((TOTAL_TESTS + module_total))
            TOTAL_PASSED=$((TOTAL_PASSED + module_passed))
            TOTAL_FAILED=$((TOTAL_FAILED + module_failed))
            
            echo "Module $module_name: $module_total tests, $module_passed passed, $module_failed failed"
            
            # Show detailed failure information if there are failures
            if [ "$module_failed" -gt 0 ]; then
                failure_file="$TEST_TEMP_DIR/test_failures.txt"
                if [ -f "$failure_file" ]; then
                    echo ""
                    cat "$failure_file"
                    echo ""
                    rm -f "$failure_file"  # Clean up
                fi
            fi
        else
            echo "ERROR: Could not parse test results from module $module_name"
            echo "Exit code: $exit_code, Output: $output"
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
        fi
    else
        echo "ERROR: Failed to run test module $module_name (exit code: $exit_code)"
        echo "Output: $output"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
done

echo ""
echo "======================================"
echo "Test Results Summary"
echo "======================================"
echo "Total tests run: $TOTAL_TESTS"
echo "Total passed: $TOTAL_PASSED"  
echo "Total failed: $TOTAL_FAILED"

if [ $TOTAL_FAILED -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
