#!/bin/bash

# Utility Module
# Contains helper functions used across the system

# Generate human-friendly model name
get_friendly_name() {
    local filepath="$1"
    local basename=$(basename "$filepath")

    # Get first word before first dash
    local first_word=$(echo "$basename" | cut -d'-' -f1)

    # Find pattern like "109B" or "7B" etc
    local size_pattern=$(echo "$basename" | grep -o '[0-9]\+B' | head -1)

    if [ -z "$size_pattern" ]; then
        # If no B pattern found, just return the first word
        echo "$first_word"
    else
        # Capitalize first letter of first word
        first_word="$(echo ${first_word:0:1} | tr '[:lower:]' '[:upper:]')${first_word:1}"
        echo "$first_word $size_pattern"
    fi
}

# Detect what GPU backend llama.cpp was built with
detect_gpu_backend() {
    # Check what llama.cpp was actually built with, not what's available
    local llama_binary="$LLAMA_PATH/bin/llama-cli"
    
    if [ ! -f "$llama_binary" ]; then
        echo "cpu"
        return
    fi
    
    # Check if ldd is available
    if ! command -v ldd &> /dev/null; then
        echo "cpu"
        return
    fi
    
    # Check linked libraries to determine build type
    local libs=$(ldd "$llama_binary" 2>/dev/null)
    
    # Check for ROCm/HIP build
    if echo "$libs" | grep -q "rocm\|hip\|amdhip"; then
        echo "rocm"
    # Check for CUDA build
    elif echo "$libs" | grep -q "cuda\|cublas\|cudart"; then
        echo "cuda"
    # Check for Vulkan build
    elif [ -f "$LLAMA_PATH/bin/libggml-vulkan.so" ] || echo "$libs" | grep -q "vulkan"; then
        echo "vulkan"
    # Check for Metal (macOS)
    elif echo "$libs" | grep -q "Metal\|metal"; then
        echo "metal"
    else
        # CPU-only build
        echo "cpu"
    fi
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