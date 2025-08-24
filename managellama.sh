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

# Source all modules
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/ui.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/models.sh"
source "$SCRIPT_DIR/server.sh"
source "$SCRIPT_DIR/system.sh"
source "$SCRIPT_DIR/autostart.sh"

# Main loop
main() {
    # Show splash screen on startup
    show_splash
    
    while true; do
        show_header
        show_menu
        read choice

        case $choice in
            1) view_models ;;
            2) change_models_dir ;;
            3) download_model ;;
            4) start_server ;;
            5) view_stats ;;
            6) watch_logs ;;
            7) stop_server ;;
            8) restart_server ;;
            9) test_model ;;
            10) benchmark_model ;;
            11) convert_model ;;
            12) system_info ;;
            13) update_llama ;;
            14) list_devices ;;
            15) test_tool_calling ;;
            16) configure_autostart ;;
            17) start_with_saved_config ;;
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
