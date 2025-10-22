#!/bin/bash

# Autostart Module
# Handles auto-start configuration and systemd service management

# Enable strict mode
set -u  # Exit on undefined variables

configure_autostart() {
    show_header
    echo -e "${YELLOW}${BOLD}Configure Auto-Start on Boot${NC}\n"
    
    if [ ! -f "$PERSISTENT_CONFIG" ]; then
        echo -e "${RED}No saved configuration found!${NC}"
        echo -e "Please start the server first using option 4 to save a configuration."
        press_any_key
        return
    fi
    
    if is_autostart_enabled; then
        echo -e "${GREEN}Auto-start is currently ENABLED${NC}\n"

        if prompt_yes_no "Do you want to disable auto-start?"; then
            if sudo systemctl list-unit-files | grep -q "$SYSTEMD_SERVICE_NAME"; then
                sudo systemctl disable "$SYSTEMD_SERVICE_NAME"
                echo -e "${GREEN}Auto-start disabled${NC}"
            else
                echo -e "${YELLOW}Service not found. Cleaning up any existing service file...${NC}"
                if [ -f "$SYSTEMD_SERVICE_FILE" ]; then
                    sudo rm -f "$SYSTEMD_SERVICE_FILE"
                fi
                echo -e "${GREEN}Auto-start disabled${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}Auto-start is currently DISABLED${NC}\n"

        if prompt_yes_no "Do you want to enable auto-start on boot?"; then
            echo -e "\n${CYAN}Creating systemd service...${NC}"

            # Check if realpath is available, fall back to readlink
            if command -v realpath &> /dev/null; then
                SCRIPT_PATH=$(realpath "$0")
            elif command -v readlink &> /dev/null; then
                SCRIPT_PATH=$(readlink -f "$0")
            else
                SCRIPT_PATH="$0"
            fi

            # Try to create systemd service directory
            if ! sudo mkdir -p "$(dirname "$SYSTEMD_SERVICE_FILE")" 2>/dev/null; then
                echo -e "${RED}Error: Cannot create systemd service directory${NC}"
                echo -e "${YELLOW}You may need sudo privileges or check system permissions${NC}"
                press_any_key
                return $E_PERMISSION
            fi

            # Try to write systemd service file
            if ! sudo tee "$SYSTEMD_SERVICE_FILE" > /dev/null << EOSVC
[Unit]
Description=Llama.cpp Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$LLAMA_PATH
ExecStart=/bin/bash -c 'source $PERSISTENT_CONFIG && cd $LLAMA_PATH && ./bin/llama-server -m "\$MODEL" -a "\$MODEL_ALIAS" -t \$THREADS -c \$CONTEXT -b \$BATCH --host \$HOST --port \$PORT --parallel \$PARALLEL -ngl \$GPU_LAYERS --split-mode \$SPLIT_MODE --main-gpu \$MAIN_GPU \$([[ "\$USE_JINJA" = "y" || "\$USE_JINJA" = "Y" ]] && echo "--jinja") \$([[ -n "\$CHAT_TEMPLATE" && ("\$USE_JINJA" = "y" || "\$USE_JINJA" = "Y") ]] && echo "--chat-template \"\$CHAT_TEMPLATE\"") \$([[ "\$NO_KV_OFFLOAD" = "y" || "\$NO_KV_OFFLOAD" = "Y" ]] && echo "--no-kv-offload") \$([[ -n "\$SYSTEM_PROMPT" ]] && echo "--system-prompt \"\$SYSTEM_PROMPT\"") \$([[ "\${CONTEXT_SHIFT:-y}" = "y" || "\${CONTEXT_SHIFT:-y}" = "Y" ]] && echo "--ctx-shift 1") --keep \${KEEP_TOKENS:-2048}'
Restart=on-failure
RestartSec=10
User=$USER

[Install]
WantedBy=multi-user.target
EOSVC
            then
                echo -e "${RED}Error: Failed to create systemd service file${NC}"
                echo -e "${YELLOW}Check sudo privileges and /etc/systemd/system permissions${NC}"
                press_any_key
                return $E_PERMISSION
            fi

            # Set proper ownership and permissions
            sudo chown root:root "$SYSTEMD_SERVICE_FILE" || {
                echo -e "${YELLOW}Warning: Could not set service file ownership${NC}"
            }

            sudo chmod 644 "$SYSTEMD_SERVICE_FILE" || {
                echo -e "${YELLOW}Warning: Could not set service file permissions${NC}"
            }

            # Validate service file syntax
            if ! sudo systemd-analyze verify "$SYSTEMD_SERVICE_FILE" 2>/dev/null; then
                echo -e "${YELLOW}Warning: Service file validation failed${NC}"
                echo -e "${CYAN}Service may still work, but check syntax${NC}"
            fi

            # Try to reload systemd and enable service
            if ! sudo systemctl daemon-reload 2>/dev/null; then
                echo -e "${RED}Error: Failed to reload systemd${NC}"
                echo -e "${YELLOW}Check systemctl permissions${NC}"
                press_any_key
                return $E_COMMAND_FAILED
            fi

            if ! sudo systemctl enable "$SYSTEMD_SERVICE_NAME" 2>/dev/null; then
                echo -e "${RED}Error: Failed to enable service${NC}"
                echo -e "${YELLOW}Check systemctl permissions${NC}"
                press_any_key
                return $E_COMMAND_FAILED
            fi

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

is_autostart_enabled() {
    if [ -f "$SYSTEMD_SERVICE_FILE" ]; then
        if command -v systemctl &> /dev/null && sudo systemctl is-enabled --quiet "$SYSTEMD_SERVICE_NAME" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}
