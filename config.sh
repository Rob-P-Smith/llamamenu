#!/bin/bash

export LLAMA_PATH="${LLAMA_PATH:-$HOME/Downloads/llama.cpp/build}"
export DEFAULT_MODELS_DIR="$HOME/Models"
export MODELS_DIR="${MODELS_DIR:-$DEFAULT_MODELS_DIR}"
export CONFIG_FILE="$HOME/.managellama.conf"
export PERSISTENT_CONFIG="$HOME/.llama-server-persistent.conf"
export SERVICE_PID_FILE="/tmp/llama-server.pid"
export SERVICE_LOG_FILE="/tmp/llama-server.log"
export SYSTEMD_SERVICE_NAME="llama-server"
export SYSTEMD_SERVICE_FILE="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"
export DEFAULT_SYSTEM_PROMPT="You are an expert coding LLM. Respond in the language you are given, use tool calls to complete complex tasks more efficiently. Avoid comments in generated code. If you do not know an answer, respond that you do not know"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE" 2>/dev/null || {
            echo -e "${YELLOW}Warning: Failed to load config file${NC}"
        }
    fi
}

save_config() {
    echo "MODELS_DIR=\"$MODELS_DIR\"" > "$CONFIG_FILE"
    echo "LLAMA_PATH=\"$LLAMA_PATH\"" >> "$CONFIG_FILE"
}

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
TEMPLATE_MODE="${16}"
TEMPERATURE=${17:-0.7}
TOP_K=${18:-40}
TOP_P=${19:-0.95}
MIN_P=${20:-0.05}
REPEAT_PENALTY=${21:-1.1}
GPU_BACKEND="${22:-$(detect_gpu_backend)}"
SYSTEM_PROMPT="${23}"
KEEP_TOKENS=${24:-2048}
EOCONF
    echo -e "${GREEN}Persistent configuration saved to $PERSISTENT_CONFIG${NC}"
}

load_persistent_config() {
    if [ -f "$PERSISTENT_CONFIG" ]; then
        source "$PERSISTENT_CONFIG"
        return 0
    fi
    return 1
}

generate_server_config_summary() {
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

load_config