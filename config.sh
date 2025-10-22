#!/bin/bash

# Enable strict mode for configuration module
set -u  # Exit on undefined variables

# XDG_RUNTIME_DIR for user-specific temp files
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
    RUNTIME_DIR="$XDG_RUNTIME_DIR/llama-server"
else
    RUNTIME_DIR="/tmp/llama-server-$USER"
fi

# Create runtime directory if it doesn't exist
mkdir -p "$RUNTIME_DIR" 2>/dev/null || {
    echo -e "${YELLOW}Warning: Could not create runtime directory, using /tmp${NC}" >&2
    RUNTIME_DIR="/tmp"
}

export LLAMA_PATH="${LLAMA_PATH:-$HOME/Downloads/llama.cpp/build}"
export DEFAULT_MODELS_DIR="$HOME/Models"
export MODELS_DIR="${MODELS_DIR:-$DEFAULT_MODELS_DIR}"
export CONFIG_FILE="$HOME/.managellama.conf"
export PERSISTENT_CONFIG="$HOME/.llama-server-persistent.conf"
export SERVICE_PID_FILE="$RUNTIME_DIR/llama-server.pid"
export SERVICE_LOG_FILE="$RUNTIME_DIR/llama-server.log"
export TEMP_CONFIG_FILE="$RUNTIME_DIR/llama-server-config.sh"
export SYSTEMD_SERVICE_NAME="llama-server"
export SYSTEMD_SERVICE_FILE="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"
export DEFAULT_SYSTEM_PROMPT="You are an expert coding LLM. Respond in the language you are given, use tool calls to complete complex tasks more efficiently. Avoid comments in generated code. If you do not know an answer, respond that you do not know"

validate_llama_installation() {
    local required_bins=("llama-server" "llama-cli")
    for bin in "${required_bins[@]}"; do
        if [ ! -f "$LLAMA_PATH/bin/$bin" ]; then
            echo -e "${RED}Error: Required binary not found: $LLAMA_PATH/bin/$bin${NC}"
            return 1
        fi
    done
    return 0
}

validate_config_file() {
    local config="$1"

    # Check if file is readable
    if [ ! -r "$config" ]; then
        echo -e "${RED}Config file not readable: $config${NC}"
        return 1
    fi

    # Check for shell injection attempts
    if grep -qE '[$`]|\$\(' "$config" 2>/dev/null; then
        echo -e "${RED}Config file contains potentially dangerous content${NC}"
        return 1
    fi

    # Check for valid variable assignments only (allow empty lines and comments)
    local invalid_lines=0
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        # Skip comments
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        # Check format: VARIABLE="value" or VARIABLE=value
        if ! [[ "$line" =~ ^[A-Z_]+=\"[^\"]*\"$ || "$line" =~ ^[A-Z_]+=[^[:space:]]+$ ]]; then
            echo -e "${YELLOW}Invalid line in config: $line${NC}"
            ((invalid_lines++))
        fi
    done < "$config"

    if [ $invalid_lines -gt 0 ]; then
        echo -e "${YELLOW}Config file format may be invalid${NC}"
        return 1
    fi

    return 0
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        if validate_config_file "$CONFIG_FILE"; then
            source "$CONFIG_FILE" 2>/dev/null || {
                echo -e "${RED}Config file validation passed but sourcing failed${NC}"
                echo -e "${YELLOW}Using default configuration${NC}"
                return 1
            }
        else
            echo -e "${RED}Config file validation failed, using defaults${NC}"
            return 1
        fi
    fi
    return 0
}

cleanup_old_runtime_files() {
    # Clean up old runtime files (older than 7 days)
    if [ -d "$RUNTIME_DIR" ]; then
        find "$RUNTIME_DIR" -type f -mtime +7 -delete 2>/dev/null || true
    fi
}

save_config() {
    # Try to write config, handle permission errors
    if ! echo "MODELS_DIR=\"$MODELS_DIR\"" > "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${RED}Error: Cannot write to config file: $CONFIG_FILE${NC}" >&2
        echo -e "${YELLOW}Check file permissions or use a different location${NC}" >&2
        return $E_PERMISSION
    fi

    if ! echo "LLAMA_PATH=\"$LLAMA_PATH\"" >> "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${RED}Error: Cannot append to config file: $CONFIG_FILE${NC}" >&2
        return $E_PERMISSION
    fi

    return $E_SUCCESS
}

setup_paths_interactive() {
    # Check if LLAMA_PATH is valid
    if [ -z "$LLAMA_PATH" ] || [ ! -d "$LLAMA_PATH" ]; then
        echo -e "${YELLOW}Llama.cpp path not configured or not found.${NC}"
        echo -n "Enter llama.cpp build directory path: "
        read llama_input
        # Expand tilde
        llama_input="${llama_input/#\~/$HOME}"
        LLAMA_PATH="$llama_input"

        # Validate the path
        if [ ! -d "$LLAMA_PATH" ]; then
            echo -e "${RED}Error: Directory does not exist: $LLAMA_PATH${NC}"
            return 1
        fi

        # Validate binaries exist
        if ! validate_llama_installation; then
            echo -e "${RED}Error: Required binaries not found in $LLAMA_PATH/bin/${NC}"
            echo -e "${YELLOW}Please ensure llama.cpp is properly built${NC}"
            return 1
        fi

        save_config
        echo -e "${GREEN}Llama.cpp path configured successfully!${NC}"
    fi

    # Check if MODELS_DIR is valid
    if [ ! -d "$MODELS_DIR" ]; then
        echo -e "${YELLOW}Models directory does not exist: $MODELS_DIR${NC}"

        if prompt_yes_no "Create it now?" "Y"; then
            mkdir -p "$MODELS_DIR" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Models directory created: $MODELS_DIR${NC}"
                save_config
            else
                echo -e "${RED}Failed to create models directory${NC}"
                echo -n "Enter alternative models directory path: "
                read models_input
                # Expand tilde
                models_input="${models_input/#\~/$HOME}"
                MODELS_DIR="$models_input"
                mkdir -p "$MODELS_DIR" 2>/dev/null
                save_config
            fi
        else
            echo -n "Enter models directory path: "
            read models_input
            # Expand tilde
            models_input="${models_input/#\~/$HOME}"
            MODELS_DIR="$models_input"
            mkdir -p "$MODELS_DIR" 2>/dev/null
            save_config
        fi
    fi

    return 0
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
TOP_K=${18:-20}
TOP_P=${19:-0.8}
MIN_P=${20:-0.0}
REPEAT_PENALTY=${21:-1.0}
GPU_BACKEND="${22:-$(detect_gpu_backend)}"
SYSTEM_PROMPT="${23}"
KEEP_TOKENS=${24:-2048}
CACHE_REUSE=${25:-512}
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
        if [ ! -z "$CACHE_REUSE" ] && [ "$CACHE_REUSE" -gt 0 ]; then
            echo -e "  ${GREEN}Prefix Caching:${NC} Enabled (chunk size: $CACHE_REUSE)"
        fi
        return 0
    else
        echo -e "${YELLOW}No saved server configuration found${NC}"
        return 1
    fi
}

load_config