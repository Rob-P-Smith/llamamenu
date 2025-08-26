#!/bin/bash

# Templates Module
# Handles server configuration templates

# Templates file location - use the directory of the main script if SCRIPT_DIR not set
SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")}"
export TEMPLATES_FILE="$SCRIPT_DIR/templates.json"

# Initialize templates file if it doesn't exist
init_templates_file() {
    if [ ! -f "$TEMPLATES_FILE" ]; then
        echo '{}' > "$TEMPLATES_FILE"
    fi
}

# List all templates
list_templates() {
    show_header
    echo -e "${YELLOW}${BOLD}Server Configuration Templates${NC}\n"
    
    init_templates_file
    
    # Check if Python3 is available
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Python3 is required but not installed.${NC}"
        echo -e "${YELLOW}Please install Python3 to use templates feature.${NC}"
        press_any_key
        return
    fi
    
    # Check if templates file has any templates
    template_count=$(python3 -c "import json; data=json.load(open('$TEMPLATES_FILE')); print(len(data))" 2>/dev/null || echo "0")
    
    if [ "$template_count" = "0" ]; then
        echo -e "${YELLOW}No templates found.${NC}"
        echo -e "${CYAN}Create templates by saving server configurations.${NC}"
    else
        echo -e "${CYAN}Available templates:${NC}\n"
        python3 -c "
import json
with open('$TEMPLATES_FILE') as f:
    data = json.load(f)
    for i, (name, config) in enumerate(data.items(), 1):
        print(f'  ${CYAN}{i})${NC} {name}')
        print(f'      Model: {config.get(\"MODEL_ALIAS\", \"Unknown\")}')
        print(f'      GPU Layers: {config.get(\"GPU_LAYERS\", \"0\")}')
        print(f'      Context: {config.get(\"CONTEXT\", \"4096\")}')
        print(f'      Temperature: {config.get(\"TEMPERATURE\", \"0.7\")}')
        print()
" 2>/dev/null || echo -e "${RED}Error reading templates${NC}"
    fi
    
    press_any_key
}

# Save current server config as template
save_current_as_template() {
    show_header
    echo -e "${YELLOW}${BOLD}Save Current Server Configuration as Template${NC}\n"
    
    # Check if server is running
    if [ ! -f "$SERVICE_PID_FILE" ] || ! kill -0 $(cat "$SERVICE_PID_FILE") 2>/dev/null; then
        echo -e "${RED}No server is currently running!${NC}"
        echo -e "${YELLOW}Start a server first to save its configuration.${NC}"
        press_any_key
        return
    fi
    
    # Check if config exists
    if [ ! -f /tmp/llama-server-config.sh ]; then
        echo -e "${RED}No server configuration found!${NC}"
        press_any_key
        return
    fi
    
    # Load current config
    source /tmp/llama-server-config.sh
    
    echo -e "${CYAN}Current server configuration:${NC}"
    echo -e "  Model: ${GREEN}$MODEL_ALIAS${NC}"
    echo -e "  GPU Layers: ${GREEN}$GPU_LAYERS${NC}"
    echo -e "  Context: ${GREEN}$CONTEXT${NC}"
    echo -e "  Temperature: ${GREEN}${TEMPERATURE:-0.7}${NC}"
    echo -e "  Host: ${GREEN}$HOST:$PORT${NC}"
    
    echo -n -e "\n${GREEN}Enter template name: ${NC}"
    read template_name
    
    if [ -z "$template_name" ]; then
        echo -e "${RED}Template name cannot be empty!${NC}"
        press_any_key
        return
    fi
    
    init_templates_file
    
    # Save template using Python for proper JSON handling
    python3 -c "
import json

# Load existing templates
with open('$TEMPLATES_FILE', 'r') as f:
    templates = json.load(f)

# Add new template
templates['$template_name'] = {
    'MODEL': '$MODEL',
    'MODEL_ALIAS': '$MODEL_ALIAS',
    'THREADS': ${THREADS:-$(nproc)},
    'CONTEXT': ${CONTEXT:-4096},
    'BATCH': ${BATCH:-2048},
    'HOST': '${HOST:-0.0.0.0}',
    'PORT': ${PORT:-8080},
    'PARALLEL': ${PARALLEL:-4},
    'GPU_LAYERS': ${GPU_LAYERS:-999},
    'SPLIT_MODE': '${SPLIT_MODE:-layer}',
    'MAIN_GPU': ${MAIN_GPU:-0},
    'NO_KV_OFFLOAD': '${NO_KV_OFFLOAD:-n}',
    'USE_JINJA': '${USE_JINJA:-N}',
    'CHAT_TEMPLATE': '${CHAT_TEMPLATE:-}',
    'TEMPLATE_MODE': '${TEMPLATE_MODE:-omit}',
    'KV_CACHE_TYPE': '${KV_CACHE_TYPE:-}',
    'TEMPERATURE': ${TEMPERATURE:-0.7},
    'TOP_K': ${TOP_K:-40},
    'TOP_P': ${TOP_P:-0.95},
    'MIN_P': ${MIN_P:-0.05},
    'REPEAT_PENALTY': ${REPEAT_PENALTY:-1.1}
}

# Save templates
with open('$TEMPLATES_FILE', 'w') as f:
    json.dump(templates, f, indent=2)

print('\033[0;32mTemplate saved successfully!\033[0m')
" 2>/dev/null && echo || echo -e "${RED}Error saving template${NC}"
    
    press_any_key
}

# Start server from template
start_from_template() {
    show_header
    echo -e "${YELLOW}${BOLD}Start Server from Template${NC}\n"
    
    init_templates_file
    
    # Check if templates exist
    template_count=$(python3 -c "import json; data=json.load(open('$TEMPLATES_FILE')); print(len(data))" 2>/dev/null || echo "0")
    
    if [ "$template_count" = "0" ]; then
        echo -e "${RED}No templates found!${NC}"
        echo -e "${YELLOW}Create templates by saving server configurations.${NC}"
        press_any_key
        return
    fi
    
    # Check if already running
    if [ -f "$SERVICE_PID_FILE" ] && kill -0 $(cat "$SERVICE_PID_FILE") 2>/dev/null; then
        echo -e "${RED}Server is already running! (PID: $(cat $SERVICE_PID_FILE))${NC}"
        echo -e "Stop it first before starting a new instance."
        press_any_key
        return
    fi
    
    # List templates
    echo -e "${CYAN}Available templates:${NC}\n"
    templates=()
    while IFS= read -r template; do
        templates+=("$template")
    done < <(python3 -c "
import json
with open('$TEMPLATES_FILE') as f:
    data = json.load(f)
    for name in data.keys():
        print(name)
" 2>/dev/null)
    
    for i in "${!templates[@]}"; do
        template_name="${templates[$i]}"
        echo -e "${CYAN}$((i+1)))${NC} $template_name"
        
        # Show template details
        python3 -c "
import json
with open('$TEMPLATES_FILE') as f:
    data = json.load(f)
    config = data['$template_name']
    print(f\"      Model: {config.get('MODEL_ALIAS', 'Unknown')}\")
    print(f\"      GPU: {config.get('GPU_LAYERS', '0')} layers | Context: {config.get('CONTEXT', '4096')}\")
    print(f\"      Temp: {config.get('TEMPERATURE', '0.7')} | Top-K: {config.get('TOP_K', '40')}\")
" 2>/dev/null
        echo
    done
    
    echo -n -e "${GREEN}Select template number: ${NC}"
    read template_choice
    
    if ! [[ "$template_choice" =~ ^[0-9]+$ ]] || [ "$template_choice" -lt 1 ] || [ "$template_choice" -gt ${#templates[@]} ]; then
        echo -e "${RED}Invalid selection!${NC}"
        press_any_key
        return
    fi
    
    selected_template="${templates[$((template_choice-1))]}"
    
    echo -e "\n${CYAN}Loading template: ${BOLD}$selected_template${NC}"
    
    # Load template configuration
    eval "$(python3 -c "
import json
with open('$TEMPLATES_FILE') as f:
    data = json.load(f)
    config = data['$selected_template']
    for key, value in config.items():
        if isinstance(value, str):
            print(f\"{key}='{value}'\")
        else:
            print(f\"{key}={value}\")
" 2>/dev/null)"
    
    # Check if model exists
    if [ ! -f "$MODEL" ]; then
        echo -e "\n${RED}Model file not found: $MODEL${NC}"
        echo -e "${YELLOW}The model may have been moved or deleted.${NC}"
        press_any_key
        return
    fi
    
    echo -e "\nStarting server with template configuration..."
    echo -e "Model: $MODEL_ALIAS"
    echo -e "GPU Layers: $GPU_LAYERS | Split Mode: $SPLIT_MODE"
    echo -e "Context: $CONTEXT | Temperature: $TEMPERATURE"
    
    # Build command
    server_cmd="./bin/llama-server \
        -m \"$MODEL\" \
        -a \"$MODEL_ALIAS\" \
        -t $THREADS \
        -c $CONTEXT \
        -b $BATCH \
        --host $HOST \
        --port $PORT \
        --parallel $PARALLEL \
        -ngl $GPU_LAYERS \
        --split-mode $SPLIT_MODE \
        --main-gpu $MAIN_GPU \
        --temp $TEMPERATURE \
        --top-k $TOP_K \
        --top-p $TOP_P \
        --min-p $MIN_P \
        --repeat-penalty $REPEAT_PENALTY"
    
    # Add Jinja flag if enabled
    if [ "$USE_JINJA" = "y" ] || [ "$USE_JINJA" = "Y" ]; then
        server_cmd="$server_cmd --jinja"
        # Only add chat-template parameter based on TEMPLATE_MODE
        if [ "$TEMPLATE_MODE" = "specified" ] && [ ! -z "$CHAT_TEMPLATE" ]; then
            server_cmd="$server_cmd --chat-template \"$CHAT_TEMPLATE\""
        elif [ "$TEMPLATE_MODE" = "auto" ]; then
            server_cmd="$server_cmd --chat-template \"\""
        fi
    fi
    
    # Add KV cache quantization if specified
    if [ ! -z "$KV_CACHE_TYPE" ]; then
        server_cmd="$server_cmd --cache-type-k $KV_CACHE_TYPE --cache-type-v $KV_CACHE_TYPE --flash-attn"
    fi
    
    if [ "$NO_KV_OFFLOAD" = "y" ] || [ "$NO_KV_OFFLOAD" = "Y" ]; then
        server_cmd="$server_cmd --no-kv-offload"
    fi
    
    cd "$LLAMA_PATH"
    eval "nohup $server_cmd > \"$SERVICE_LOG_FILE\" 2>&1 &"
    
    server_pid=$!
    echo $server_pid > "$SERVICE_PID_FILE"
    
    # Save config to temp for restart
    cat > /tmp/llama-server-config.sh << EOFC
MODEL="$MODEL"
MODEL_ALIAS="$MODEL_ALIAS"
THREADS=$THREADS
CONTEXT=$CONTEXT
BATCH=$BATCH
HOST=$HOST
PORT=$PORT
PARALLEL=$PARALLEL
GPU_LAYERS=$GPU_LAYERS
SPLIT_MODE=$SPLIT_MODE
MAIN_GPU=$MAIN_GPU
NO_KV_OFFLOAD="$NO_KV_OFFLOAD"
USE_JINJA="$USE_JINJA"
CHAT_TEMPLATE="$CHAT_TEMPLATE"
TEMPLATE_MODE="$TEMPLATE_MODE"
KV_CACHE_TYPE="$KV_CACHE_TYPE"
TEMPERATURE=$TEMPERATURE
TOP_K=$TOP_K
TOP_P=$TOP_P
MIN_P=$MIN_P
REPEAT_PENALTY=$REPEAT_PENALTY
EOFC
    
    sleep 3
    
    if kill -0 $server_pid 2>/dev/null; then
        echo -e "\n${GREEN}Server started successfully from template!${NC}"
        echo -e "PID: $server_pid"
        echo -e "URL: http://$HOST:$PORT"
    else
        echo -e "\n${RED}Failed to start server!${NC}"
        rm -f "$SERVICE_PID_FILE"
        echo -e "\nLast 10 lines of log:"
        tail -10 "$SERVICE_LOG_FILE"
    fi
    
    press_any_key
}

# Edit templates file
edit_templates() {
    show_header
    echo -e "${YELLOW}${BOLD}Edit Templates File${NC}\n"
    
    init_templates_file
    
    # Check for available text editor
    local editor=""
    if command -v nano &> /dev/null; then
        editor="nano"
    elif command -v vi &> /dev/null; then
        editor="vi"
    elif command -v vim &> /dev/null; then
        editor="vim"
    else
        echo -e "${RED}No text editor found (nano, vi, or vim).${NC}"
        echo -e "${YELLOW}Please install a text editor to edit templates.${NC}"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Opening templates file in $editor...${NC}"
    echo -e "${YELLOW}Be careful to maintain valid JSON format!${NC}\n"
    
    $editor "$TEMPLATES_FILE"
    
    # Validate JSON after editing
    if python3 -c "import json; json.load(open('$TEMPLATES_FILE'))" 2>/dev/null; then
        echo -e "\n${GREEN}Templates file is valid JSON.${NC}"
    else
        echo -e "\n${RED}Warning: Templates file has JSON errors!${NC}"
        echo -e "${YELLOW}Fix the errors or templates may not work properly.${NC}"
    fi
    
    press_any_key
}

# Delete a template
delete_template() {
    show_header
    echo -e "${YELLOW}${BOLD}Delete Template${NC}\n"
    
    init_templates_file
    
    # Check if templates exist
    template_count=$(python3 -c "import json; data=json.load(open('$TEMPLATES_FILE')); print(len(data))" 2>/dev/null || echo "0")
    
    if [ "$template_count" = "0" ]; then
        echo -e "${RED}No templates found!${NC}"
        press_any_key
        return
    fi
    
    # List templates
    echo -e "${CYAN}Available templates:${NC}\n"
    templates=()
    while IFS= read -r template; do
        templates+=("$template")
    done < <(python3 -c "
import json
with open('$TEMPLATES_FILE') as f:
    data = json.load(f)
    for name in data.keys():
        print(name)
" 2>/dev/null)
    
    for i in "${!templates[@]}"; do
        echo -e "${CYAN}$((i+1)))${NC} ${templates[$i]}"
    done
    
    echo -n -e "\n${GREEN}Select template to delete (0 to cancel): ${NC}"
    read template_choice
    
    if [ "$template_choice" = "0" ]; then
        echo -e "${YELLOW}Deletion cancelled.${NC}"
        press_any_key
        return
    fi
    
    if ! [[ "$template_choice" =~ ^[0-9]+$ ]] || [ "$template_choice" -lt 1 ] || [ "$template_choice" -gt ${#templates[@]} ]; then
        echo -e "${RED}Invalid selection!${NC}"
        press_any_key
        return
    fi
    
    selected_template="${templates[$((template_choice-1))]}"
    
    echo -n -e "\n${RED}Are you sure you want to delete '$selected_template'? (y/N): ${NC}"
    read -n 1 confirm
    echo
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        python3 -c "
import json
with open('$TEMPLATES_FILE', 'r') as f:
    templates = json.load(f)
del templates['$selected_template']
with open('$TEMPLATES_FILE', 'w') as f:
    json.dump(templates, f, indent=2)
print('\033[0;32mTemplate deleted successfully!\033[0m')
" 2>/dev/null && echo || echo -e "${RED}Error deleting template${NC}"
    else
        echo -e "${YELLOW}Deletion cancelled.${NC}"
    fi
    
    press_any_key
}