#!/bin/bash

# Configuration Management Module
# Handles all configuration-related operations

# Default configuration paths
export LLAMA_PATH="${LLAMA_PATH:-$HOME/Downloads/llama.cpp/build}"
export DEFAULT_MODELS_DIR="$HOME/Models"
export MODELS_DIR="${MODELS_DIR:-$DEFAULT_MODELS_DIR}"
export CONFIG_FILE="$HOME/.managellama.conf"
export PERSISTENT_CONFIG="$HOME/.llama-server-persistent.conf"
export SERVICE_PID_FILE="/tmp/llama-server.pid"
export SERVICE_LOG_FILE="/tmp/llama-server.log"
export SYSTEMD_SERVICE_NAME="llama-server"
export SYSTEMD_SERVICE_FILE="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"

# Load config if exists
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Save config
save_config() {
    echo "MODELS_DIR=\"$MODELS_DIR\"" > "$CONFIG_FILE"
    echo "LLAMA_PATH=\"$LLAMA_PATH\"" >> "$CONFIG_FILE"
}

# Save persistent server config
save_persistent_config() {
    cat > "$PERSISTENT_CONFIG" << EOCONF
MODEL="$1"
MODEL_ALIAS="$2"
THREADS=$3
CONTEXT=$4
BATCH=$5
HOST=$6
PORT=$7
PARALLEL=$8
GPU_LAYERS=$9
SPLIT_MODE=${10}
MAIN_GPU=${11}
NO_KV_OFFLOAD="${12}"
USE_JINJA="${13}"
CHAT_TEMPLATE="${14}"
KV_CACHE_TYPE="${15}"
EOCONF
    echo -e "${GREEN}Persistent configuration saved to $PERSISTENT_CONFIG${NC}"
}

# Load persistent server config
load_persistent_config() {
    if [ -f "$PERSISTENT_CONFIG" ]; then
        source "$PERSISTENT_CONFIG"
        return 0
    fi
    return 1
}

# Get server config summary
get_server_config_summary() {
    if load_persistent_config; then
        echo -e "${CYAN}Saved Server Configuration:${NC}"
        echo -e "  ${GREEN}Model:${NC} $MODEL_ALIAS"
        echo -e "  ${GREEN}GPU Layers:${NC} $GPU_LAYERS"
        echo -e "  ${GREEN}Context:${NC} $CONTEXT tokens"
        echo -e "  ${GREEN}Host:${NC} $HOST:$PORT"
        if [ ! -z "$KV_CACHE_TYPE" ]; then
            echo -e "  ${GREEN}KV Cache:${NC} ${KV_CACHE_TYPE^^} quantization"
        fi
        if [ "$USE_JINJA" = "y" ] || [ "$USE_JINJA" = "Y" ]; then
            echo -e "  ${GREEN}Tool Calling:${NC} Enabled (Jinja)"
        fi
        return 0
    else
        echo -e "${YELLOW}No saved server configuration found${NC}"
        return 1
    fi
}

# Initialize configuration
load_config