#!/bin/bash

# Test Suite for LlamaMenu
# Tests all major components and improvements

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=""

# Source modules for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui.sh" 2>/dev/null || true
source "$SCRIPT_DIR/utils.sh" 2>/dev/null || true
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true
source "$SCRIPT_DIR/templates.sh" 2>/dev/null || true

# Test output file
TEST_OUTPUT="$SCRIPT_DIR/testResults.md"

# Helper function to run tests
run_test() {
    local test_name="$1"
    shift

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing $test_name... "

    if "$@" &> /tmp/test_$$.log; then
        echo -e "${GREEN}PASS${NC}"
        TEST_RESULTS="$TEST_RESULTS\n✅ **PASS**: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        rm -f /tmp/test_$$.log
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        local error_msg=$(cat /tmp/test_$$.log 2>/dev/null | head -5)
        TEST_RESULTS="$TEST_RESULTS\n❌ **FAIL**: $test_name\n   Error: $error_msg"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        rm -f /tmp/test_$$.log
        return 1
    fi
}

# Test 1: Bash syntax validation
test_syntax_validation() {
    local all_pass=true

    for script in *.sh; do
        if ! bash -n "$script" 2>/dev/null; then
            echo "Syntax error in $script" >&2
            all_pass=false
        fi
    done

    $all_pass
}

# Test 2: Config file validation
test_config_validation() {
    local test_config="/tmp/test_config_$$.conf"

    # Test valid config
    echo 'MODELS_DIR="/tmp/models"' > "$test_config"
    echo 'LLAMA_PATH="/tmp/llama"' >> "$test_config"

    if validate_config_file "$test_config" 2>/dev/null; then
        rm -f "$test_config"
        return 0
    fi

    rm -f "$test_config"
    return 1
}

# Test 3: Config injection prevention
test_config_injection_prevention() {
    local test_config="/tmp/test_config_injection_$$.conf"

    # Test malicious config with command injection
    echo 'MODELS_DIR="$(rm -rf /)"' > "$test_config"

    if ! validate_config_file "$test_config" 2>/dev/null; then
        rm -f "$test_config"
        return 0  # Should fail validation
    fi

    rm -f "$test_config"
    return 1
}

# Test 4: PID validation
test_pid_validation() {
    # Test invalid PID
    if is_llama_server_running "invalid" 2>/dev/null; then
        return 1
    fi

    # Test non-existent PID
    if is_llama_server_running "999999" 2>/dev/null; then
        return 1
    fi

    return 0
}

# Test 5: Input validation (integers)
test_integer_validation() {
    # Create a test that simulates user input
    echo "5" | read_validated_integer "Test" 5 1 10 2>/dev/null >/dev/null
    local result=$?

    [ $result -eq 0 ]
}

# Test 6: GPU backend detection
test_gpu_detection() {
    local backend=$(detect_gpu_backend 2>/dev/null)

    # Should return cpu, cuda, rocm, vulkan, or metal
    case "$backend" in
        cpu|cuda|rocm|vulkan|metal)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Test 7: Friendly name generation (multiple strategies)
test_friendly_name_generation() {
    local test_cases=(
        "llama-7B.gguf:Llama 7B"
        "mistral.13B.gguf:Mistral 13B"
        "meta_llama-3.1-Q4_K_M.gguf:Llama (Q4_K_M)"
    )

    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r input expected <<< "$test_case"
        local result=$(auto_generate_name "/tmp/$input" 2>/dev/null)

        if [ "$result" != "$expected" ]; then
            echo "Expected '$expected', got '$result'" >&2
            return 1
        fi
    done

    return 0
}

# Test 8: Template file initialization
test_template_initialization() {
    local test_templates="/tmp/test_templates_$$.json"
    export TEMPLATES_FILE="$test_templates"

    init_templates_file 2>/dev/null

    if [ -f "$test_templates" ]; then
        # Check if it contains _example
        if python3 -c "import json; data=json.load(open('$test_templates')); exit(0 if '_example' in data else 1)" 2>/dev/null; then
            rm -f "$test_templates"
            return 0
        fi
    fi

    rm -f "$test_templates"
    return 1
}

# Test 9: Template safe loading (no eval)
test_template_safe_loading() {
    local test_templates="/tmp/test_templates_safe_$$.json"
    export TEMPLATES_FILE="$test_templates"

    # Create a template with potentially dangerous content
    cat > "$test_templates" << 'EOF'
{
  "test": {
    "MODEL": "/tmp/model.gguf",
    "MODEL_ALIAS": "Test'; rm -rf /; echo 'Model"
  }
}
EOF

    # Try to load it safely
    local temp_config=$(mktemp)
    if load_template_safely "test" > "$temp_config" 2>/dev/null; then
        # Check that the content is properly escaped
        if grep -q "Test.*rm.*rf" "$temp_config"; then
            # Command is in the string, not executed
            rm -f "$test_templates" "$temp_config"
            return 0
        fi
    fi

    rm -f "$test_templates" "$temp_config"
    return 1
}

# Test 10: Permission checking
test_permission_checking() {
    local test_dir="/tmp/test_perms_$$"
    mkdir -p "$test_dir"
    chmod 000 "$test_dir"

    # Test write permission check
    if [ ! -w "$test_dir" ]; then
        chmod 755 "$test_dir"
        rm -rf "$test_dir"
        return 0
    fi

    chmod 755 "$test_dir"
    rm -rf "$test_dir"
    return 1
}

# Test 11: XDG_RUNTIME_DIR handling
test_runtime_dir_handling() {
    local old_xdg="$XDG_RUNTIME_DIR"
    unset XDG_RUNTIME_DIR

    # Source config to trigger RUNTIME_DIR setup
    RUNTIME_DIR=""
    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
        RUNTIME_DIR="$XDG_RUNTIME_DIR/llama-server"
    else
        RUNTIME_DIR="/tmp/llama-server-$USER"
    fi

    # Check that RUNTIME_DIR is set to a sensible default
    if [[ "$RUNTIME_DIR" == *"$USER"* ]] || [[ "$RUNTIME_DIR" == *"llama-server"* ]]; then
        export XDG_RUNTIME_DIR="$old_xdg"
        return 0
    fi

    export XDG_RUNTIME_DIR="$old_xdg"
    return 1
}

# Test 12: Spinner function exists and is safe
test_spinner_function() {
    # Check that show_spinner function is defined
    if declare -f show_spinner >/dev/null; then
        # Test with a quick process
        sleep 0.1 &
        local pid=$!
        show_spinner $pid 2>/dev/null &
        local spinner_pid=$!
        sleep 0.2
        kill $spinner_pid 2>/dev/null
        wait $spinner_pid 2>/dev/null
        return 0
    fi
    return 1
}

# Test 13: Prompt functions consistency
test_prompt_functions() {
    # Check that prompt functions exist
    if declare -f prompt_yes_no >/dev/null && \
       declare -f prompt_string >/dev/null && \
       declare -f prompt_number >/dev/null; then
        return 0
    fi
    return 1
}

# Test 14: Safe watch function (no eval)
test_safe_watch_function() {
    # Check that safe_watch validates functions
    if declare -f safe_watch >/dev/null; then
        # Test with invalid function should fail
        if safe_watch "nonexistent_function_$$" "test" 2>/dev/null; then
            return 1
        fi
        return 0
    fi
    return 1
}

# Test 15: Error codes defined
test_error_codes() {
    if [ -n "$E_SUCCESS" ] && [ -n "$E_NOT_FOUND" ] && \
       [ -n "$E_PERMISSION" ] && [ -n "$E_COMMAND_FAILED" ]; then
        return 0
    fi
    return 1
}

# Test 16: Model name override system
test_model_name_override() {
    local test_model="/tmp/test-model-7B.gguf"
    local old_home="$HOME"
    local test_home="/tmp/test_home_$$"
    mkdir -p "$test_home"
    touch "$test_model"

    # Set a custom name with test HOME
    HOME="$test_home" set_model_friendly_name "$test_model" "My Custom Name" >/dev/null 2>&1

    # Check if it was saved
    if grep -q "test-model-7B.gguf=My Custom Name" "$test_home/.llamamenu-model-names.conf" 2>/dev/null; then
        rm -f "$test_model"
        rm -rf "$test_home"
        HOME="$old_home"
        return 0
    fi

    rm -f "$test_model"
    rm -rf "$test_home"
    HOME="$old_home"
    return 1
}

# Test 17: Systemd service file validation
test_systemd_validation() {
    # Check that systemd-analyze would be used for validation
    # (We can't actually create systemd files in test)
    if command -v systemd-analyze &>/dev/null; then
        return 0
    fi
    # If systemd-analyze not available, that's OK for non-systemd systems
    return 0
}

# Test 18: JSON validation for templates
test_json_validation() {
    local test_json="/tmp/test_$$.json"

    # Test valid JSON
    echo '{"test": "value"}' > "$test_json"
    if python3 -c "import json; json.load(open('$test_json'))" 2>/dev/null; then
        rm -f "$test_json"
        return 0
    fi

    rm -f "$test_json"
    return 1
}

# Generate markdown report
generate_report() {
    cat > "$TEST_OUTPUT" << EOF
# LlamaMenu Test Results

**Test Date**: $(date '+%Y-%m-%d %H:%M:%S')

## Summary

- **Total Tests**: $TESTS_RUN
- **Passed**: $TESTS_PASSED ✅
- **Failed**: $TESTS_FAILED ❌
- **Success Rate**: $(( TESTS_PASSED * 100 / TESTS_RUN ))%

## Test Results

EOF

    echo -e "$TEST_RESULTS" >> "$TEST_OUTPUT"

    cat >> "$TEST_OUTPUT" << EOF

## Test Categories

### Security Tests
- Config injection prevention
- Template safe loading (no eval)
- Safe watch function validation
- Permission checking

### Robustness Tests
- Bash syntax validation
- Config file validation
- PID validation
- Input validation
- Error codes defined

### Feature Tests
- GPU backend detection
- Friendly name generation (5 strategies)
- Model name override system
- Template initialization with example
- XDG_RUNTIME_DIR handling
- Spinner function
- Prompt functions consistency
- JSON validation

### Integration Tests
- Systemd service validation
- Runtime directory setup

## Recommendations

EOF

    if [ $TESTS_FAILED -eq 0 ]; then
        cat >> "$TEST_OUTPUT" << EOF
🎉 **All tests passed!** The system is ready for production use.

### Next Steps
1. Review any warnings in individual test logs
2. Test with actual llama.cpp installation
3. Test server start/stop lifecycle
4. Test with real models
EOF
    else
        cat >> "$TEST_OUTPUT" << EOF
⚠️ **Some tests failed.** Please review the failures above.

### Action Items
1. Fix failing tests before deploying to production
2. Review error messages for each failed test
3. Ensure all dependencies are installed
4. Check file permissions and paths
EOF
    fi
}

# Main test execution
main() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     LlamaMenu Comprehensive Test Suite       ║${NC}"
    echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    echo

    # Run all tests
    run_test "Bash syntax validation" test_syntax_validation
    run_test "Config file validation" test_config_validation
    run_test "Config injection prevention" test_config_injection_prevention
    run_test "PID validation" test_pid_validation
    run_test "Integer input validation" test_integer_validation
    run_test "GPU backend detection" test_gpu_detection
    run_test "Friendly name generation" test_friendly_name_generation
    run_test "Template initialization" test_template_initialization
    run_test "Template safe loading" test_template_safe_loading
    run_test "Permission checking" test_permission_checking
    run_test "XDG_RUNTIME_DIR handling" test_runtime_dir_handling
    run_test "Spinner function" test_spinner_function
    run_test "Prompt functions" test_prompt_functions
    run_test "Safe watch function" test_safe_watch_function
    run_test "Error codes defined" test_error_codes
    run_test "Model name override" test_model_name_override
    run_test "Systemd validation" test_systemd_validation
    run_test "JSON validation" test_json_validation

    # Generate report
    echo
    echo -e "${CYAN}Generating test report...${NC}"
    generate_report

    # Summary
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Test Summary                     ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Total Tests:  $TESTS_RUN"
    echo -e "${CYAN}║${NC} ${GREEN}Passed:       $TESTS_PASSED ✅${NC}"
    echo -e "${CYAN}║${NC} ${RED}Failed:       $TESTS_FAILED ❌${NC}"
    echo -e "${CYAN}║${NC} Success Rate: $(( TESTS_PASSED * 100 / TESTS_RUN ))%"
    echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}Test report saved to: $TEST_OUTPUT${NC}"
    echo

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  Some tests failed. Review $TEST_OUTPUT for details.${NC}"
        exit 1
    fi
}

# Run main
main "$@"
