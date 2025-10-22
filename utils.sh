#!/bin/bash

# Utility Module
# Contains helper functions used across the system

# Enable strict mode
set -u  # Exit on undefined variables

# Standard exit/return codes
readonly E_SUCCESS=0
readonly E_NOT_FOUND=1
readonly E_PERMISSION=2
readonly E_INVALID_INPUT=3
readonly E_COMMAND_FAILED=4
readonly E_CONFIG_ERROR=5
readonly E_NETWORK_ERROR=6
readonly E_ALREADY_RUNNING=7

# Check if a PID is a running llama-server process
is_llama_server_running() {
    local pid="$1"

    # Validate PID format
    if [ -z "$pid" ] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Check if PID exists and is llama-server
    if [ -d "/proc/$pid" ]; then
        local cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
        if echo "$cmdline" | grep -q "llama-server"; then
            return 0
        fi
    fi

    return 1
}

# Auto-generate friendly name with multiple parsing strategies
auto_generate_name() {
    local filepath="$1"
    local basename=$(basename "$filepath" .gguf)

    # Strategy 1: Look for ModelName-SizeB pattern (e.g., llama-7B, mistral-13B)
    if [[ "$basename" =~ ([A-Za-z0-9]+)-([0-9]+\.?[0-9]*[BbMmKk]) ]]; then
        local name="${BASH_REMATCH[1]}"
        local size="${BASH_REMATCH[2]}"
        echo "${name^} ${size^^}"
        return
    fi

    # Strategy 2: Look for ModelName.SizeB pattern (e.g., llama.7B)
    if [[ "$basename" =~ ([A-Za-z0-9]+)\.([0-9]+\.?[0-9]*[BbMmKk]) ]]; then
        local name="${BASH_REMATCH[1]}"
        local size="${BASH_REMATCH[2]}"
        echo "${name^} ${size^^}"
        return
    fi

    # Strategy 3: HuggingFace format (org_model-version-quant) (e.g., meta_llama-3.1-Q4_K_M)
    if [[ "$basename" =~ ([A-Za-z0-9]+)_([A-Za-z0-9]+)-.*-([QIq][0-9_KkMm]+) ]]; then
        local org="${BASH_REMATCH[1]}"
        local model="${BASH_REMATCH[2]}"
        local quant="${BASH_REMATCH[3]}"
        echo "${model^} (${quant^^})"
        return
    fi

    # Strategy 4: Look for any size pattern anywhere (e.g., model-name-7B-instruct)
    if [[ "$basename" =~ ([0-9]+\.?[0-9]*[BbMmKk]) ]]; then
        local size="${BASH_REMATCH[1]}"
        # Get first word before first dash
        local first_word=$(echo "$basename" | cut -d'-' -f1)
        first_word="${first_word^}"
        echo "$first_word ${size^^}"
        return
    fi

    # Strategy 5: Just use first 30 characters
    if [ ${#basename} -gt 30 ]; then
        echo "${basename:0:27}..."
    else
        echo "$basename"
    fi
}

# Set custom friendly name for a model
set_model_friendly_name() {
    local filepath="$1"
    local friendly_name="$2"
    local basename=$(basename "$filepath")
    local names_file="$HOME/.llamamenu-model-names.conf"

    # Remove existing entry
    if [ -f "$names_file" ]; then
        grep -vF "$basename=" "$names_file" > "$names_file.tmp" 2>/dev/null
        mv "$names_file.tmp" "$names_file"
    fi

    # Add new entry
    echo "$basename=$friendly_name" >> "$names_file"
    echo -e "${GREEN}Model name set to: $friendly_name${NC}"
}

# Generate human-friendly model name (with user override support)
get_friendly_name() {
    local filepath="$1"
    local basename=$(basename "$filepath")

    # Check for user override first
    local names_file="$HOME/.llamamenu-model-names.conf"
    if [ -f "$names_file" ]; then
        local override=$(grep -F "$basename=" "$names_file" 2>/dev/null | cut -d= -f2-)
        if [ -n "$override" ]; then
            echo "$override"
            return
        fi
    fi

    # Auto-generate name if no override found
    auto_generate_name "$filepath"
}

# Detect what GPU backend llama.cpp was built with
detect_gpu_backend() {
    # Check what llama.cpp was actually built with, not what's available
    local llama_binary="$LLAMA_PATH/bin/llama-cli"
    
    if [ ! -f "$llama_binary" ]; then
        echo "cpu"
        return
    fi

    # Method 1: Check linked libraries
    if command -v ldd &> /dev/null; then
        local libs=$(ldd "$llama_binary" 2>/dev/null)

        if echo "$libs" | grep -q "rocm\|hip\|amdhip"; then
            echo "rocm"
            return
        fi

        if echo "$libs" | grep -q "cuda\|cublas\|cudart"; then
            echo "cuda"
            return
        fi

        if [ -f "$LLAMA_PATH/bin/libggml-vulkan.so" ] || echo "$libs" | grep -q "vulkan"; then
            echo "vulkan"
            return
        fi

        if echo "$libs" | grep -q "Metal\|metal"; then
            echo "metal"
            return
        fi
    fi

    # Method 2: Run llama-cli with --help and check output
    if "$llama_binary" --help 2>&1 | grep -qi "cuda"; then
        echo "cuda"
        return
    fi

    if "$llama_binary" --help 2>&1 | grep -qi "rocm\|hip"; then
        echo "rocm"
        return
    fi

    if "$llama_binary" --help 2>&1 | grep -qi "vulkan"; then
        echo "vulkan"
        return
    fi

    # Method 3: Check for Vulkan library file
    if [ -f "$LLAMA_PATH/bin/libggml-vulkan.so" ]; then
        echo "vulkan"
        return
    fi

    # Default to CPU
    echo "cpu"
}

# Show spinner for long-running operations
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    echo -n " "
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Standardized yes/no prompt (always requires Enter)
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-N}"
    local response

    if [ "$default" = "Y" ] || [ "$default" = "y" ]; then
        echo -n -e "${prompt} (Y/n): "
    else
        echo -n -e "${prompt} (y/N): "
    fi

    read response

    response=${response:-$default}
    case "${response,,}" in
        y) return 0 ;;
        *) return 1 ;;
    esac
}

# Standardized string prompt
prompt_string() {
    local prompt="$1"
    local default="$2"
    local response

    if [ -n "$default" ]; then
        echo -n -e "${prompt} (default: ${default}): "
    else
        echo -n -e "${prompt}: "
    fi

    read response
    echo "${response:-$default}"
}

# Standardized number prompt with validation
prompt_number() {
    local prompt="$1"
    local default="$2"
    local min="${3:-1}"
    local max="${4:-999999}"

    while true; do
        local value=$(prompt_string "$prompt" "$default")

        if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$min" ] && [ "$value" -le "$max" ]; then
            echo "$value"
            return 0
        fi

        echo -e "${RED}Please enter a number between $min and $max${NC}"
    done
}

# Detect available GPU hardware on system
detect_available_gpu() {
    # This detects what GPU hardware is available, not what llama.cpp uses
    if command -v nvidia-smi &> /dev/null; then
        echo "cuda"
    elif command -v rocminfo &> /dev/null && rocminfo 2>/dev/null | grep -q "HSA Agents"; then
        echo "rocm"
    elif command -v vulkaninfo &> /dev/null && vulkaninfo 2>/dev/null | grep -q "deviceName"; then
        echo "vulkan"
    else
        echo "cpu"
    fi
}

# Get GPU info
get_gpu_info() {
    local gpu_info=""
    local built_backend=$(detect_gpu_backend 2>/dev/null || echo "cpu")
    local available_backend=$(detect_available_gpu 2>/dev/null || echo "cpu")
    
    # Show what llama.cpp was built with
    case $built_backend in
        cuda)
            if command -v nvidia-smi &> /dev/null; then
                local cuda_device=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
                if [ ! -z "$cuda_device" ]; then
                    gpu_info="${GREEN}CUDA: ${cuda_device}${NC}"
                fi
            else
                gpu_info="${YELLOW}CUDA build (nvidia-smi not found)${NC}"
            fi
            ;;
        rocm)
            # Try rocm-smi first for accurate GPU name
            local rocm_device=""
            if command -v rocm-smi &> /dev/null; then
                rocm_device=$(rocm-smi --showproductname 2>/dev/null | grep "Card series" | head -1 | sed 's/.*Card series://g' | xargs)
            fi
            # If rocm-smi didn't work, try rocminfo
            if [ -z "$rocm_device" ]; then
                rocm_device=$(rocminfo 2>/dev/null | grep "Marketing Name" | grep -v "Processor" | head -1 | sed 's/.*Marketing Name://g' | xargs)
            fi
            if [ -z "$rocm_device" ]; then
                rocm_device=$(rocminfo 2>/dev/null | grep "Name:" | grep "gfx" | head -1 | awk -F: '{print $2}' | xargs)
            fi
            # If still nothing, check for any GPU agent
            if [ -z "$rocm_device" ]; then
                rocm_device=$(rocminfo 2>/dev/null | grep -A2 "Agent " | grep "Name:" | grep -v "CPU" | head -1 | awk -F: '{print $2}' | xargs)
            fi
            if [ ! -z "$rocm_device" ]; then
                gpu_info="${GREEN}ROCm: ${rocm_device}${NC}"
            else
                # Fall back to PCI info if ROCm doesn't report properly
                local pci_gpu=$(lspci | grep -iE "vga|3d|display" | head -1 | sed 's/.*: //')
                if [ ! -z "$pci_gpu" ]; then
                    gpu_info="${GREEN}ROCm Available: ${pci_gpu}${NC}"
                fi
            fi
            ;;
        vulkan)
            local vulkan_device=$(vulkaninfo 2>/dev/null | grep "deviceName" | head -1 | cut -d'=' -f2 | xargs)
            if [ ! -z "$vulkan_device" ]; then
                gpu_info="${YELLOW}Vulkan: ${vulkan_device}${NC}"
            fi
            ;;
        cpu)
            local pci_gpu=$(lspci | grep -iE "vga|3d|display" | head -1)
            if [ ! -z "$pci_gpu" ]; then
                gpu_info="${RED}CPU Only${NC} (GPU available: $(echo $pci_gpu | cut -d':' -f3 | cut -c1-30))"
            else
                gpu_info="${RED}CPU Only${NC} (No GPU detected)"
            fi
            ;;
    esac
    
    # If built backend doesn't match available, show warning
    if [ "$built_backend" != "$available_backend" ] && [ "$built_backend" != "cpu" ] && [ "$available_backend" != "cpu" ]; then
        gpu_info="$gpu_info ${YELLOW}[Built: ${built_backend^^}, Available: ${available_backend^^}]${NC}"
    elif [ "$built_backend" = "cpu" ] && [ "$available_backend" != "cpu" ]; then
        gpu_info="$gpu_info ${YELLOW}[Rebuild with ${available_backend^^} for GPU support]${NC}"
    fi

    echo "$gpu_info"
}

# Check if auto-start is enabled
is_autostart_enabled() {
    if [ -f "$SYSTEMD_SERVICE_FILE" ]; then
        systemctl is-enabled "$SYSTEMD_SERVICE_NAME" &>/dev/null
        return $?
    fi
    return 1
}

# Read and validate integer input with re-prompting
read_validated_integer() {
    local prompt="$1"
    local default="$2"
    local min="${3:-1}"
    local max="${4:-999999}"
    local value

    while true; do
        echo -n -e "$prompt (default: $default, range: $min-$max): "
        read value
        value=${value:-$default}

        if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$min" ] && [ "$value" -le "$max" ]; then
            echo "$value"
            return 0
        fi

        echo -e "${RED}Invalid input. Please enter a number between $min and $max${NC}"
    done
}

# Read and validate float input with re-prompting
read_validated_float() {
    local prompt="$1"
    local default="$2"
    local min="${3:-0.0}"
    local max="${4:-2.0}"
    local value

    while true; do
        echo -n -e "$prompt (default: $default, range: $min-$max): "
        read value
        value=${value:-$default}

        # Check if it's a valid number (integer or float)
        if [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]] || [[ "$value" =~ ^[0-9]*\.[0-9]+$ ]]; then
            # Use awk for float comparison (more portable than bc)
            if awk -v val="$value" -v min="$min" -v max="$max" 'BEGIN { exit !(val >= min && val <= max) }'; then
                echo "$value"
                return 0
            fi
        fi

        echo -e "${RED}Invalid input. Please enter a number between $min and $max${NC}"
    done
}

# Safe tail with interrupt handling
safe_tail() {
    local file="$1"
    local lines="${2:-50}"
    
    echo -e "${YELLOW}Showing last $lines lines. Press 'q' to return to menu${NC}\n"
    
    # Create a temp file for the tail output
    local temp_file=$(mktemp)
    tail -n "$lines" "$file" > "$temp_file"
    
    # Use less with appropriate options
    less -R +G "$temp_file"
    
    rm -f "$temp_file"
}