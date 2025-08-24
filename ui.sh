#!/bin/bash

# UI Module
# Handles all UI-related functions including colors, headers, and menus

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m' # No Color
export BOLD='\033[1m'

# Clear screen and show splash
show_splash() {
    clear
    echo -e "${CYAN}${BOLD}PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP${NC}"
    echo -e "${CYAN}${BOLD}         Llama.cpp Server Management System${NC}"
    echo -e "${GREEN}         Simplified GPU-accelerated LLM deployment and management${NC}"
    echo -e "${CYAN}${BOLD}PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP${NC}"
    echo
    
    # Show saved configuration if exists
    if [ -f "$PERSISTENT_CONFIG" ]; then
        get_server_config_summary
    else
        echo -e "${YELLOW}No saved server configuration${NC}"
        echo -e "${CYAN}Use option 4 to configure and start a server${NC}"
    fi
    
    echo
    echo -e "${CYAN}PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP${NC}"
    echo -e "${YELLOW}Press any key to continue to main menu...${NC}"
    read -n 1 -s -r
}

# Clear screen and show header
show_header() {
    clear
    echo -e "${CYAN}${BOLD}TPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPW${NC}"
    echo -e "${CYAN}${BOLD}Q       LLAMA.CPP MANAGEMENT SYSTEM v2.2 (Modular)        Q${NC}"
    echo -e "${CYAN}${BOLD}ZPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP]${NC}"
    echo -e "${GREEN}Models Directory: ${NC}$MODELS_DIR"
    echo -e "${GREEN}Llama.cpp Path: ${NC}$LLAMA_PATH"
    echo -e "${GREEN}GPU Device: ${NC}$(get_gpu_info)"

    # Check if server is running
    if [ -f "$SERVICE_PID_FILE" ] && kill -0 $(cat "$SERVICE_PID_FILE") 2>/dev/null; then
        echo -e "${GREEN}Server Status: ${NC}${GREEN}� Running (PID: $(cat $SERVICE_PID_FILE))${NC}"
        # Show GPU layers and Jinja status if config exists
        if [ -f /tmp/llama-server-config.sh ]; then
            source /tmp/llama-server-config.sh
            if [ ! -z "$GPU_LAYERS" ]; then
                echo -e "${GREEN}GPU Layers: ${NC}${MAGENTA}$GPU_LAYERS layers offloaded${NC}"
            fi
            if [ "$USE_JINJA" = "y" ] || [ "$USE_JINJA" = "Y" ]; then
                echo -e "${GREEN}Tool Calling: ${NC}${MAGENTA}� Enabled (Jinja)${NC}"
            fi
        fi
    else
        echo -e "${GREEN}Server Status: ${NC}${RED}� Stopped${NC}"
    fi
    
    # Check auto-start status
    if is_autostart_enabled; then
        echo -e "${GREEN}Auto-start: ${NC}${GREEN}� Enabled${NC}"
    else
        echo -e "${GREEN}Auto-start: ${NC}${YELLOW}� Disabled${NC}"
    fi
    
    echo -e "${CYAN}PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP${NC}\n"
}

# Main menu
show_menu() {
    echo -e "${YELLOW}${BOLD}Main Menu:${NC}"
    echo -e "${CYAN}  1)${NC} View all models in models directory"
    echo -e "${CYAN}  2)${NC} Change models directory"
    echo -e "${CYAN}  3)${NC} Download new model"
    echo -e "${CYAN}  4)${NC} Start llama server (interactive setup)"
    echo -e "${CYAN}  5)${NC} View server stats (live)"
    echo -e "${CYAN}  6)${NC} Watch server logs"
    echo -e "${CYAN}  7)${NC} Stop llama server"
    echo -e "${CYAN}  8)${NC} Restart llama server"
    echo -e "${CYAN}  9)${NC} Test model (interactive chat)"
    echo -e "${CYAN} 10)${NC} Benchmark model"
    echo -e "${CYAN} 11)${NC} Convert model format"
    echo -e "${CYAN} 12)${NC} System info & GPU details"
    echo -e "${CYAN} 13)${NC} Update llama.cpp"
    echo -e "${CYAN} 14)${NC} List available devices"
    echo -e "${CYAN} 15)${NC} Test tool calling (function call test)"
    echo -e "${CYAN} 16)${NC} Configure auto-start on boot"
    echo -e "${CYAN} 17)${NC} Start server with saved configuration"
    echo -e "${RED}  0)${NC} Exit"
    echo -e "${CYAN}PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP${NC}"
    echo -n -e "${GREEN}Enter choice [0-17]: ${NC}"
}

# Press any key to continue
press_any_key() {
    echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
    read -n 1 -s -r
}

# Safe watch function that can be interrupted without killing the script
safe_watch() {
    local command="$1"
    local message="${2:-Press 'q' to return to menu}"
    
    echo -e "${YELLOW}$message${NC}\n"
    
    # Set up trap to handle interruption
    trap 'return 0' INT
    
    while true; do
        # Check for 'q' key press with timeout
        if read -t 1 -n 1 key; then
            if [[ $key = "q" ]]; then
                break
            fi
        fi
        
        # Execute the command
        eval "$command"
    done
    
    # Reset trap
    trap - INT
    return 0
}