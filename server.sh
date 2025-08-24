#!/bin/bash

# Server Module  
# Handles all server-related operations

# Start server with GPU support and Jinja option
start_server() {
    show_header
    echo -e "${YELLOW}${BOLD}Start Llama Server with GPU Acceleration${NC}\n"

    # Check if already running
    if [ -f "$SERVICE_PID_FILE" ] && kill -0 $(cat "$SERVICE_PID_FILE") 2>/dev/null; then
        echo -e "${RED}Server is already running! (PID: $(cat $SERVICE_PID_FILE))${NC}"
        echo -e "Stop it first before starting a new instance."
        press_any_key
        return
    fi

    # List available models
    echo -e "${CYAN}Available models:${NC}\n"

    models=()
    while IFS= read -r model; do
        models+=("$model")
    done < <(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | sort)

    if [ ${#models[@]} -eq 0 ]; then
        echo -e "${RED}No models found! Download a model first.${NC}"
        press_any_key
        return
    fi

    for i in "${!models[@]}"; do
        friendly_name=$(get_friendly_name "${models[$i]}")
        basename=$(basename "${models[$i]}")
        echo -e "${BLUE}$((i+1)))${NC} ${BOLD}$friendly_name${NC}"
        echo -e "    $basename"
    done

    echo -n -e "\n${GREEN}Select model number: ${NC}"
    read model_choice

    if ! [[ "$model_choice" =~ ^[0-9]+$ ]] || [ "$model_choice" -lt 1 ] || [ "$model_choice" -gt ${#models[@]} ]; then
        echo -e "${RED}Invalid selection!${NC}"
        press_any_key
        return
    fi

    selected_model="${models[$((model_choice-1))]}"
    selected_model_name=$(get_friendly_name "$selected_model")

    # GPU Configuration
    echo -e "\n${MAGENTA}${BOLD}GPU Configuration:${NC}"

    echo -n -e "Number of layers to offload to GPU (default: 999 for full offload): "
    read gpu_layers
    gpu_layers=${gpu_layers:-999}

    echo -n -e "Split mode (none/layer/row, default: layer): "
    read split_mode
    split_mode=${split_mode:-layer}

    echo -n -e "Main GPU index (default: 0): "
    read main_gpu
    main_gpu=${main_gpu:-0}

    echo -n -e "Disable KV offload? (y/N): "
    read -n 1 no_kv_offload
    echo

    # KV Cache Quantization Configuration
    echo -e "\n${MAGENTA}${BOLD}KV Cache Quantization:${NC}"
    echo -e "${YELLOW}Reduce memory usage by quantizing the KV cache${NC}"
    echo -e "${RED}WARNING: KV cache quantization requires flash attention${NC}"
    echo -e "${RED}         This may not work with Vulkan/AMD GPUs${NC}"
    echo -e "${CYAN}TIP: For AMD GPUs, use smaller model quantization (Q4_K_M) instead${NC}"
    echo -e "${BLUE}1)${NC} FP16 (default - recommended for AMD/Vulkan)"
    echo -e "${BLUE}2)${NC} Q8_0 (8-bit quantization, ~50% memory savings)"
    echo -e "${BLUE}3)${NC} Q4_0 (4-bit quantization, ~75% memory savings)"
    echo -n -e "${GREEN}Select KV cache type [1-3]: ${NC}"
    read kv_cache_choice
    
    case $kv_cache_choice in
        2) 
            kv_cache_type="q8_0"
            echo -e "${YELLOW}Note: Enabling flash attention for KV quantization${NC}"
            echo -n -e "Try without flash attention if it fails? (y/N): "
            read -n 1 try_without_flash
            echo
            ;;
        3) 
            kv_cache_type="q4_0"
            echo -e "${YELLOW}Note: Enabling flash attention for KV quantization${NC}"
            echo -n -e "Try without flash attention if it fails? (y/N): "
            read -n 1 try_without_flash
            echo
            ;;
        *) kv_cache_type="" ;;  # Default FP16
    esac

    # Tool Calling / Jinja Configuration
    echo -e "\n${MAGENTA}${BOLD}Tool Calling Configuration:${NC}"
    echo -e "${YELLOW}Enable Jinja templating for tool/function calling support?${NC}"
    echo -e "This is required for AI agents and function calling in Continue/OpenWebUI."
    echo -n -e "Enable Jinja? (Y/n): "
    read -n 1 use_jinja
    echo
    use_jinja=${use_jinja:-Y}

    # Chat template selection if Jinja is enabled
    chat_template=""
    if [ "$use_jinja" = "y" ] || [ "$use_jinja" = "Y" ]; then
        echo -e "\n${CYAN}Select chat template:${NC}"
        echo -e "${BLUE}1)${NC} Auto-detect (default)"
        echo -e "${BLUE}2)${NC} Qwen"
        echo -e "${BLUE}3)${NC} ChatML"
        echo -e "${BLUE}4)${NC} Llama3"
        echo -e "${BLUE}5)${NC} Custom path"
        echo -n -e "${GREEN}Select template [1-5]: ${NC}"
        read template_choice
        
        case $template_choice in
            2) chat_template="qwen" ;;
            3) chat_template="chatml" ;;
            4) chat_template="llama3" ;;
            5) 
                echo -n -e "Enter template path or name: "
                read chat_template
                ;;
            *) chat_template="" ;;  # Auto-detect
        esac
    fi

    # Get parameters
    cpu_threads=$(nproc)
    echo -e "\n${CYAN}Server Configuration:${NC}"

    echo -n -e "Number of CPU threads (default: $cpu_threads): "
    read threads
    threads=${threads:-$cpu_threads}

    echo -n -e "Context size (default: 16384): "
    read context
    context=${context:-16384}

    echo -n -e "Batch size (default: 2048): "
    read batch
    batch=${batch:-2048}

    echo -n -e "Port (default: 8080): "
    read port
    port=${port:-8080}

    echo -n -e "Host (default: 0.0.0.0): "
    read host
    host=${host:-0.0.0.0}

    echo -n -e "Max parallel requests (default: 4): "
    read parallel
    parallel=${parallel:-4}

    # Add model alias for friendly name
    echo -n -e "Model alias/name (default: $selected_model_name): "
    read model_alias
    model_alias=${model_alias:-$selected_model_name}

    # Build command
    server_cmd="./bin/llama-server \
        -m \"$selected_model\" \
        -a \"$model_alias\" \
        -t $threads \
        -c $context \
        -b $batch \
        --host $host \
        --port $port \
        --parallel $parallel \
        -ngl $gpu_layers \
        --split-mode $split_mode \
        --main-gpu $main_gpu"

    # Add Jinja flag if enabled
    if [ "$use_jinja" = "y" ] || [ "$use_jinja" = "Y" ]; then
        server_cmd="$server_cmd --jinja"
        if [ ! -z "$chat_template" ]; then
            server_cmd="$server_cmd --chat-template \"$chat_template\""
        fi
    fi

    # Add KV cache quantization if specified
    if [ ! -z "$kv_cache_type" ]; then
        server_cmd="$server_cmd --cache-type-k $kv_cache_type --cache-type-v $kv_cache_type"
        # Add flash attention unless user opted to try without it
        if [ "$try_without_flash" != "y" ] && [ "$try_without_flash" != "Y" ]; then
            server_cmd="$server_cmd --flash-attn"
        fi
    fi

    # Add no-kv-offload if requested
    if [ "$no_kv_offload" = "y" ] || [ "$no_kv_offload" = "Y" ]; then
        server_cmd="$server_cmd --no-kv-offload"
    fi

    # Start server in background
    echo -e "\n${CYAN}Starting server with model: ${BOLD}$model_alias${NC}"
    echo -e "${MAGENTA}GPU Layers: $gpu_layers | Split Mode: $split_mode${NC}"
    if [ ! -z "$kv_cache_type" ]; then
        echo -e "${MAGENTA}KV Cache: ${kv_cache_type^^} quantization${NC}"
    fi
    if [ "$use_jinja" = "y" ] || [ "$use_jinja" = "Y" ]; then
        echo -e "${GREEN}Tool Calling: ENABLED (Jinja)${NC}"
        if [ ! -z "$chat_template" ]; then
            echo -e "${GREEN}Chat Template: $chat_template${NC}"
        fi
    fi

    cd "$LLAMA_PATH"
    eval "nohup $server_cmd > \"$SERVICE_LOG_FILE\" 2>&1 &"

    server_pid=$!
    echo $server_pid > "$SERVICE_PID_FILE"

    # Save configs
    cat > /tmp/llama-server-config.sh << EOFC
MODEL="$selected_model"
MODEL_ALIAS="$model_alias"
THREADS=$threads
CONTEXT=$context
BATCH=$batch
HOST=$host
PORT=$port
PARALLEL=$parallel
GPU_LAYERS=$gpu_layers
SPLIT_MODE=$split_mode
MAIN_GPU=$main_gpu
NO_KV_OFFLOAD="$no_kv_offload"
USE_JINJA="$use_jinja"
CHAT_TEMPLATE="$chat_template"
KV_CACHE_TYPE="$kv_cache_type"
EOFC

    # Also save as persistent config
    save_persistent_config "$selected_model" "$model_alias" $threads $context $batch "$host" $port $parallel $gpu_layers "$split_mode" $main_gpu "$no_kv_offload" "$use_jinja" "$chat_template" "$kv_cache_type"

    sleep 3

    if kill -0 $server_pid 2>/dev/null; then
        echo -e "${GREEN}Server started successfully!${NC}"
        echo -e "PID: $server_pid"
        echo -e "URL: http://$host:$port"
        echo -e "Model: $model_alias"
        echo -e "GPU Layers Offloaded: $gpu_layers"
    else
        echo -e "${RED}Failed to start server! Check logs.${NC}"
        rm -f "$SERVICE_PID_FILE"
        echo -e "\nLast 10 lines of log:"
        tail -10 "$SERVICE_LOG_FILE"
    fi

    press_any_key
}

# Stop server
stop_server() {
    show_header
    echo -e "${YELLOW}${BOLD}Stop Llama Server${NC}\n"

    if [ ! -f "$SERVICE_PID_FILE" ]; then
        echo -e "${RED}No PID file found. Server might not be running.${NC}"
        press_any_key
        return
    fi

    pid=$(cat "$SERVICE_PID_FILE")

    if kill -0 $pid 2>/dev/null; then
        echo -e "Stopping server (PID: $pid)..."
        kill $pid
        sleep 2

        if kill -0 $pid 2>/dev/null; then
            echo -e "${YELLOW}Server didn't stop gracefully. Force killing...${NC}"
            kill -9 $pid
        fi

        rm -f "$SERVICE_PID_FILE"
        echo -e "${GREEN}Server stopped successfully!${NC}"
    else
        echo -e "${YELLOW}Server process not found. Cleaning up PID file.${NC}"
        rm -f "$SERVICE_PID_FILE"
    fi

    press_any_key
}

# Restart server
restart_server() {
    show_header
    echo -e "${YELLOW}${BOLD}Restart Llama Server${NC}\n"

    if [ ! -f /tmp/llama-server-config.sh ]; then
        echo -e "${RED}No previous server configuration found!${NC}"
        echo -e "Please start the server first using option 4."
        press_any_key
        return
    fi

    # Stop if running
    if [ -f "$SERVICE_PID_FILE" ] && kill -0 $(cat "$SERVICE_PID_FILE") 2>/dev/null; then
        echo -e "Stopping current server..."
        pid=$(cat "$SERVICE_PID_FILE")
        kill $pid 2>/dev/null
        sleep 2
        kill -9 $pid 2>/dev/null
        rm -f "$SERVICE_PID_FILE"
    fi

    # Load previous config
    source /tmp/llama-server-config.sh

    echo -e "Restarting with previous configuration..."
    echo -e "Model: $MODEL_ALIAS"
    echo -e "GPU Layers: $GPU_LAYERS | Split Mode: $SPLIT_MODE"
    echo -e "Threads: $THREADS, Context: $CONTEXT, Batch: $BATCH"
    echo -e "Host: $HOST:$PORT"
    if [ "$USE_JINJA" = "y" ] || [ "$USE_JINJA" = "Y" ]; then
        echo -e "Tool Calling: ENABLED (Jinja)"
    fi
    echo

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
        --main-gpu $MAIN_GPU"

    # Add Jinja flag if it was enabled
    if [ "$USE_JINJA" = "y" ] || [ "$USE_JINJA" = "Y" ]; then
        server_cmd="$server_cmd --jinja"
        if [ ! -z "$CHAT_TEMPLATE" ]; then
            server_cmd="$server_cmd --chat-template \"$CHAT_TEMPLATE\""
        fi
    fi

    # Add KV cache quantization if specified (requires flash attention)
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

    sleep 3

    if kill -0 $server_pid 2>/dev/null; then
        echo -e "${GREEN}Server restarted successfully!${NC}"
        echo -e "PID: $server_pid"
    else
        echo -e "${RED}Failed to restart server!${NC}"
        rm -f "$SERVICE_PID_FILE"
    fi

    press_any_key
}

# Start with saved config
start_with_saved_config() {
    show_header
    echo -e "${YELLOW}${BOLD}Start Server with Saved Configuration${NC}\n"
    
    if [ ! -f "$PERSISTENT_CONFIG" ]; then
        echo -e "${RED}No saved configuration found!${NC}"
        echo -e "Please start the server first using option 4 to save a configuration."
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
    
    # Load saved config
    source "$PERSISTENT_CONFIG"
    
    echo -e "Starting with saved configuration..."
    echo -e "Model: $MODEL_ALIAS"
    echo -e "GPU Layers: $GPU_LAYERS | Split Mode: $SPLIT_MODE"
    echo -e "Threads: $THREADS, Context: $CONTEXT, Batch: $BATCH"
    echo -e "Host: $HOST:$PORT"
    if [ "$USE_JINJA" = "y" ] || [ "$USE_JINJA" = "Y" ]; then
        echo -e "Tool Calling: ENABLED (Jinja)"
    fi
    echo
    
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
        --main-gpu $MAIN_GPU"
    
    # Add Jinja flag if enabled
    if [ "$USE_JINJA" = "y" ] || [ "$USE_JINJA" = "Y" ]; then
        server_cmd="$server_cmd --jinja"
        if [ ! -z "$CHAT_TEMPLATE" ]; then
            server_cmd="$server_cmd --chat-template \"$CHAT_TEMPLATE\""
        fi
    fi
    
    # Add KV cache quantization if specified (requires flash attention)
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
    
    # Also save to temp config for restart
    cp "$PERSISTENT_CONFIG" /tmp/llama-server-config.sh
    
    sleep 3
    
    if kill -0 $server_pid 2>/dev/null; then
        echo -e "${GREEN}Server started successfully!${NC}"
        echo -e "PID: $server_pid"
        echo -e "URL: http://$HOST:$PORT"
    else
        echo -e "${RED}Failed to start server!${NC}"
        rm -f "$SERVICE_PID_FILE"
    fi
    
    press_any_key
}

# View server stats with safe interrupt
view_stats() {
    show_header
    echo -e "${YELLOW}${BOLD}Server Statistics${NC}\n"

    if [ ! -f "$SERVICE_PID_FILE" ] || ! kill -0 $(cat "$SERVICE_PID_FILE") 2>/dev/null; then
        echo -e "${RED}Server is not running!${NC}"
        press_any_key
        return
    fi

    # Get server config
    if [ -f /tmp/llama-server-config.sh ]; then
        source /tmp/llama-server-config.sh
        server_url="http://$HOST:$PORT"
    else
        server_url="http://0.0.0.0:8080"
    fi

    echo -e "${CYAN}Fetching stats from $server_url/metrics${NC}"
    echo -e "${YELLOW}Press 'q' to return to menu${NC}\n"

    # Monitor stats with safe interrupt
    trap 'return 0' INT
    
    while true; do
        clear
        echo -e "${CYAN}${BOLD}Server Statistics - $(date)${NC}\n"

        # Server config info
        if [ -f /tmp/llama-server-config.sh ]; then
            source /tmp/llama-server-config.sh
            echo -e "${MAGENTA}Model: $MODEL_ALIAS | GPU Layers: $GPU_LAYERS | Context: $CONTEXT${NC}"
            if [ "$USE_JINJA" = "y" ] || [ "$USE_JINJA" = "Y" ]; then
                echo -e "${GREEN}Tool Calling: ENABLED${NC}"
            fi
            echo
        fi

        # Try to get metrics
        if command -v curl &> /dev/null; then
            echo -e "${YELLOW}Performance Metrics:${NC}"
            curl -s "$server_url/metrics" 2>/dev/null | grep -E "llama_|process_" | head -20

            echo -e "\n${YELLOW}Health Status:${NC}"
            curl -s "$server_url/health" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Unable to fetch health"

            echo -e "\n${YELLOW}Slots Status:${NC}"
            curl -s "$server_url/slots" 2>/dev/null | python3 -m json.tool 2>/dev/null | head -30
        else
            echo -e "${RED}curl not installed. Install it to view stats.${NC}"
        fi
        
        echo -e "\n${YELLOW}Press 'q' to return to menu${NC}"
        
        # Check for 'q' key press with timeout
        if read -t 2 -n 1 key; then
            if [[ $key = "q" ]]; then
                break
            fi
        fi
    done
    
    trap - INT
}

# Watch logs with safe interrupt
watch_logs() {
    show_header
    echo -e "${YELLOW}${BOLD}Server Logs${NC}\n"

    if [ ! -f "$SERVICE_LOG_FILE" ]; then
        echo -e "${RED}No log file found!${NC}"
        press_any_key
        return
    fi

    echo -e "${CYAN}Viewing $SERVICE_LOG_FILE${NC}"
    echo -e "${YELLOW}Use arrow keys to navigate, 'q' to return to menu${NC}\n"

    # Show GPU initialization info if present
    if grep -q "ggml_vulkan:" "$SERVICE_LOG_FILE" 2>/dev/null; then
        echo -e "${MAGENTA}GPU Initialization:${NC}"
        grep "ggml_vulkan:" "$SERVICE_LOG_FILE" | head -5
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
    fi

    # Use less for log viewing (allows safe exit with 'q')
    less +F "$SERVICE_LOG_FILE"
}

# Test tool calling functionality
test_tool_calling() {
    show_header
    echo -e "${YELLOW}${BOLD}Test Tool Calling / Function Call Support${NC}\n"

    if [ ! -f "$SERVICE_PID_FILE" ] || ! kill -0 $(cat "$SERVICE_PID_FILE") 2>/dev/null; then
        echo -e "${RED}Server is not running! Start it first with option 4.${NC}"
        press_any_key
        return
    fi

    # Get server config
    if [ -f /tmp/llama-server-config.sh ]; then
        source /tmp/llama-server-config.sh
        server_url="http://$HOST:$PORT"
    else
        server_url="http://0.0.0.0:8080"
    fi

    echo -e "${CYAN}Testing tool calling at $server_url${NC}\n"

    # Check if Jinja is enabled
    if [ "$USE_JINJA" != "y" ] && [ "$USE_JINJA" != "Y" ]; then
        echo -e "${YELLOW}Warning: Jinja was not enabled when starting the server.${NC}"
        echo -e "Tool calling may not work properly.\n"
    fi

    echo -e "${GREEN}Sending test function call request...${NC}\n"

    # Test request with function calling
    response=$(curl -s -X POST "$server_url/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'"$MODEL_ALIAS"'",
            "messages": [
                {
                    "role": "user",
                    "content": "What is the weather in San Francisco?"
                }
            ],
            "tools": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_weather",
                        "description": "Get the current weather for a location",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "location": {
                                    "type": "string",
                                    "description": "The city and state, e.g. San Francisco, CA"
                                },
                                "unit": {
                                    "type": "string",
                                    "enum": ["celsius", "fahrenheit"],
                                    "description": "The temperature unit"
                                }
                            },
                            "required": ["location"]
                        }
                    }
                }
            ],
            "tool_choice": "auto",
            "max_tokens": 500
        }' 2>&1)

    echo -e "${CYAN}Response:${NC}"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

    # Check response
    if echo "$response" | grep -q "jinja"; then
        echo -e "\n${RED}Tool calling requires the --jinja flag!${NC}"
        echo -e "Restart the server with Jinja enabled (option 8) to use tool calling."
    elif echo "$response" | grep -q "tool_calls\|function_call"; then
        echo -e "\n${GREEN}✓ Tool calling is working!${NC}"
        echo -e "The server successfully processed the function call request."
    elif echo "$response" | grep -q "error"; then
        echo -e "\n${YELLOW}Tool calling test returned an error.${NC}"
        echo -e "Check the server logs for more details."
    else
        echo -e "\n${YELLOW}Tool calling may be working but response format is unclear.${NC}"
        echo -e "The model might not support tool calling or needs a specific chat template."
    fi

    press_any_key
}
