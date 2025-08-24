#!/bin/bash

# Autostart Module
# Handles auto-start configuration and systemd service management

# Configure auto-start
configure_autostart() {
    show_header
    echo -e "${YELLOW}${BOLD}Configure Auto-Start on Boot${NC}\n"
    
    if [ ! -f "$PERSISTENT_CONFIG" ]; then
        echo -e "${RED}No saved configuration found!${NC}"
        echo -e "Please start the server first using option 4 to save a configuration."
        press_any_key
        return
    fi
    
    # Check current status
    if is_autostart_enabled; then
        echo -e "${GREEN}Auto-start is currently ENABLED${NC}\n"
        echo -n -e "Do you want to disable auto-start? (y/n): "
        read -n 1 disable
        echo
        
        if [ "$disable" = "y" ] || [ "$disable" = "Y" ]; then
            sudo systemctl disable "$SYSTEMD_SERVICE_NAME"
            echo -e "${GREEN}Auto-start disabled${NC}"
        fi
    else
        echo -e "${YELLOW}Auto-start is currently DISABLED${NC}\n"
        echo -n -e "Do you want to enable auto-start on boot? (y/n): "
        read -n 1 enable
        echo
        
        if [ "$enable" = "y" ] || [ "$enable" = "Y" ]; then
            # Create systemd service file
            echo -e "\n${CYAN}Creating systemd service...${NC}"
            
            # Get absolute path to this script
            SCRIPT_PATH=$(realpath "$0")
            
            sudo tee "$SYSTEMD_SERVICE_FILE" > /dev/null << EOSVC
[Unit]
Description=Llama.cpp Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$LLAMA_PATH
ExecStart=/bin/bash -c 'source $PERSISTENT_CONFIG && cd $LLAMA_PATH && ./bin/llama-server -m "\$MODEL" -a "\$MODEL_ALIAS" -t \$THREADS -c \$CONTEXT -b \$BATCH --host \$HOST --port \$PORT --parallel \$PARALLEL -ngl \$GPU_LAYERS --split-mode \$SPLIT_MODE --main-gpu \$MAIN_GPU \$([[ "\$USE_JINJA" = "y" || "\$USE_JINJA" = "Y" ]] && echo "--jinja") \$([[ -n "\$CHAT_TEMPLATE" && ("\$USE_JINJA" = "y" || "\$USE_JINJA" = "Y") ]] && echo "--chat-template \"\$CHAT_TEMPLATE\"") \$([[ "\$NO_KV_OFFLOAD" = "y" || "\$NO_KV_OFFLOAD" = "Y" ]] && echo "--no-kv-offload")'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOSVC
            
            # Reload systemd and enable service
            sudo systemctl daemon-reload
            sudo systemctl enable "$SYSTEMD_SERVICE_NAME"
            
            echo -e "${GREEN}Auto-start enabled!${NC}"
            echo -e "The server will start automatically on boot with the saved configuration."
            echo -e "\nYou can manage the service with:"
            echo -e "  sudo systemctl start $SYSTEMD_SERVICE_NAME   # Start now"
            echo -e "  sudo systemctl stop $SYSTEMD_SERVICE_NAME    # Stop"
            echo -e "  sudo systemctl status $SYSTEMD_SERVICE_NAME  # Check status"
            echo -e "  sudo journalctl -u $SYSTEMD_SERVICE_NAME -f  # View logs"
        fi
    fi
    
    press_any_key
}
