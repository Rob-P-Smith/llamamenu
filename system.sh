#!/bin/bash

# System Module
# Handles system information, GPU details, and llama.cpp updates

# Enhanced system info with GPU details
system_info() {
    show_header
    echo -e "${YELLOW}${BOLD}System Information & GPU Details${NC}\n"

    echo -e "${CYAN}CPU Information:${NC}"
    lscpu | grep -E "Model name:|CPU\(s\):|Thread|Core|Socket" | sed 's/^/  /'

    echo -e "\n${CYAN}Memory Information:${NC}"
    free -h | sed 's/^/  /'

    echo -e "\n${MAGENTA}GPU Information (Vulkan):${NC}"
    if command -v vulkaninfo &> /dev/null; then
        vulkaninfo 2>/dev/null | grep -E "deviceName|deviceType|apiVersion|driverVersion" | head -8 | sed 's/^/  /'
        echo -e "\n  ${YELLOW}Vulkan Memory:${NC}"
        vulkaninfo 2>/dev/null | grep -E "size|heap" | head -6 | sed 's/^/    /'
    else
        echo "  Vulkaninfo not found"
    fi

    echo -e "\n${CYAN}PCI GPU Devices:${NC}"
    lspci | grep -iE "vga|3d|display" | sed 's/^/  /'

    echo -e "\n${CYAN}Disk Usage (Models Directory):${NC}"
    df -h "$MODELS_DIR" | sed 's/^/  /'

    echo -e "\n${CYAN}Llama.cpp Build Info:${NC}"
    if [ -f "$LLAMA_PATH/bin/llama-cli" ]; then
        echo "  Binary: llama-cli"
        ls -lh "$LLAMA_PATH/bin/llama-cli" | awk '{print "  Size: " $5 " | Modified: " $6 " " $7 " " $8}'

        # Check for Vulkan support
        if [ -f "$LLAMA_PATH/bin/libggml-vulkan.so" ]; then
            echo -e "  ${GREEN}Vulkan Support: ENABLED${NC}"
            ls -lh "$LLAMA_PATH/bin/libggml-vulkan.so" | awk '{print "  Vulkan Library Size: " $5}'
        else
            echo -e "  ${RED}Vulkan Support: NOT FOUND${NC}"
        fi
    else
        echo "  Not found"
    fi

    # Check for Jinja support in server
    echo -e "\n${CYAN}Server Capabilities:${NC}"
    if [ -f "$LLAMA_PATH/bin/llama-server" ]; then
        if strings "$LLAMA_PATH/bin/llama-server" 2>/dev/null | grep -q "jinja"; then
            echo -e "  ${GREEN}Jinja/Tool Calling: SUPPORTED${NC}"
        else
            echo -e "  ${YELLOW}Jinja/Tool Calling: Unknown (test to verify)${NC}"
        fi
    fi

    # AMD GPU specific tools
    echo -e "\n${CYAN}AMD GPU Tools:${NC}"
    if command -v radeontop &> /dev/null; then
        echo -e "  ${GREEN}radeontop: Available${NC}"
    else
        echo -e "  ${YELLOW}radeontop: Not installed (install for GPU monitoring)${NC}"
    fi

    if command -v rocm-smi &> /dev/null; then
        echo -e "  ${GREEN}rocm-smi: Available${NC}"
        rocm-smi --showproductname 2>/dev/null | head -5 | sed 's/^/    /'
    else
        echo -e "  ${YELLOW}ROCm: Not installed${NC}"
    fi

    press_any_key
}

# Update llama.cpp
update_llama() {
    show_header
    echo -e "${YELLOW}${BOLD}Update Llama.cpp${NC}\n"

    llama_root=$(dirname "$LLAMA_PATH")

    if [ ! -d "$llama_root/.git" ]; then
        echo -e "${RED}Not a git repository!${NC}"
        echo -e "Cannot update automatically."
        press_any_key
        return
    fi

    echo -e "${CYAN}Current directory: $llama_root${NC}\n"

    cd "$llama_root"

    echo -e "Fetching updates..."
    git fetch

    echo -e "\n${CYAN}Current version:${NC}"
    git log --oneline -1

    echo -e "\n${CYAN}Latest version:${NC}"
    git log --oneline origin/master -1

    echo -n -e "\n${YELLOW}Update to latest version? (y/n): ${NC}"
    read -n 1 update
    echo

    if [ "$update" != "y" ] && [ "$update" != "Y" ]; then
        echo -e "${YELLOW}Update cancelled.${NC}"
        press_any_key
        return
    fi

    echo -e "\n${CYAN}Updating...${NC}"
    git pull origin master

    echo -e "\n${CYAN}Rebuilding with Vulkan support...${NC}"
    cd "$LLAMA_PATH"
    cmake --build . -j$(nproc)

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Update completed successfully!${NC}"

        # Verify Vulkan support still present
        if [ -f "$LLAMA_PATH/bin/libggml-vulkan.so" ]; then
            echo -e "${GREEN}Vulkan support verified!${NC}"
        else
            echo -e "${YELLOW}Warning: Vulkan library not found after rebuild${NC}"
        fi

        # Check for Jinja support
        if strings "$LLAMA_PATH/bin/llama-server" 2>/dev/null | grep -q "jinja"; then
            echo -e "${GREEN}Jinja/Tool calling support verified!${NC}"
        fi
    else
        echo -e "\n${RED}Update failed!${NC}"
    fi

    press_any_key
}

# List available devices
list_devices() {
    show_header
    echo -e "${YELLOW}${BOLD}Available Compute Devices${NC}\n"

    echo -e "${CYAN}Checking available devices...${NC}\n"

    cd "$LLAMA_PATH"
    if [ -f "./bin/llama-cli" ]; then
        ./bin/llama-cli --list-devices 2>&1 | head -20
    else
        echo -e "${RED}llama-cli not found!${NC}"
    fi

    echo -e "\n${MAGENTA}Vulkan Devices:${NC}"
    if command -v vulkaninfo &> /dev/null; then
        vulkaninfo --summary 2>/dev/null | grep -A 5 "Devices:" | sed 's/^/  /'
    else
        echo "  vulkaninfo not available"
    fi

    press_any_key
}
