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

# Get GPU info
get_gpu_info() {
    local gpu_info=""

    # Check for Vulkan
    if command -v vulkaninfo &> /dev/null; then
        local vulkan_device=$(vulkaninfo 2>/dev/null | grep "deviceName" | head -1 | cut -d'=' -f2 | xargs)
        if [ ! -z "$vulkan_device" ]; then
            gpu_info="${GREEN}Vulkan: ${vulkan_device}${NC}"
        fi
    fi

    # If no Vulkan info, check PCI devices
    if [ -z "$gpu_info" ]; then
        local pci_gpu=$(lspci | grep -iE "vga|3d|display" | head -1)
        if [ ! -z "$pci_gpu" ]; then
            gpu_info="${YELLOW}GPU: $(echo $pci_gpu | cut -d':' -f3)${NC}"
        else
            gpu_info="${RED}No GPU detected${NC}"
        fi
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