#!/bin/bash

# Llama.cpp Management System - Main Entry Point
# Modular version 2.2

# Get the directory where this script is located (resolving symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Source all modules with error handling
for module in config.sh ui.sh utils.sh models.sh server.sh system.sh autostart.sh templates.sh; do
    if [ -f "$SCRIPT_DIR/$module" ]; then
        source "$SCRIPT_DIR/$module"
    else
        echo "Error: Required module $module not found in $SCRIPT_DIR"
        exit 1
    fi
done

# Model Management submenu handler
model_management() {
    while true; do
        show_header
        show_model_menu
        read subchoice
        
        case $subchoice in
            1) view_models ;;
            2) change_models_dir ;;
            3) download_model ;;
            4) convert_model ;;
            0) break ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Server Operations submenu handler
server_operations() {
    while true; do
        show_header
        show_server_menu
        read subchoice
        
        case $subchoice in
            1) start_server ;;
            2) stop_server ;;
            3) restart_server ;;
            4) view_stats ;;
            5) watch_logs ;;
            6) start_with_saved_config ;;
            0) break ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Templates submenu handler
templates_management() {
    while true; do
        show_header
        show_templates_menu
        read subchoice
        
        case $subchoice in
            1) start_from_template ;;
            2) save_current_as_template ;;
            3) list_templates ;;
            4) edit_templates ;;
            5) delete_template ;;
            0) break ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Testing submenu handler
testing_utilities() {
    while true; do
        show_header
        show_testing_menu
        read subchoice
        
        case $subchoice in
            1) test_model ;;
            2) benchmark_model ;;
            3) test_tool_calling ;;
            0) break ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# System submenu handler
system_configuration() {
    while true; do
        show_header
        show_system_menu
        read subchoice
        
        case $subchoice in
            1) system_info ;;
            2) update_llama ;;
            3) list_devices ;;
            4) configure_autostart ;;
            0) break ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main loop
main() {
    # Show splash screen on startup
    show_splash
    
    while true; do
        show_header
        show_menu
        read choice

        case $choice in
            1) model_management ;;
            2) server_operations ;;
            3) templates_management ;;
            4) testing_utilities ;;
            5) system_configuration ;;
            0)
                echo -e "\n${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"
