#!/bin/bash

# Models Module
# Handles all model-related operations

# View models
view_models() {
    show_header
    echo -e "${YELLOW}${BOLD}Models in $MODELS_DIR:${NC}\n"

    if [ ! -d "$MODELS_DIR" ]; then
        echo -e "${RED}Models directory does not exist!${NC}"
        press_any_key
        return
    fi

    local count=0
    while IFS= read -r model; do
        ((count++))
        size=$(du -h "$model" | cut -f1)
        basename=$(basename "$model")
        friendly_name=$(get_friendly_name "$model")
        echo -e "${BLUE}$count)${NC} ${BOLD}$friendly_name${NC}"
        echo -e "    File: $basename ${CYAN}[$size]${NC}"
    done < <(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | sort)

    if [ $count -eq 0 ]; then
        echo -e "${RED}No GGUF models found in $MODELS_DIR${NC}"
    else
        echo -e "\n${GREEN}Total: $count model(s)${NC}"
    fi

    press_any_key
}

# Change models directory
change_models_dir() {
    show_header
    echo -e "${YELLOW}${BOLD}Change Models Directory${NC}\n"
    echo -e "Current directory: ${GREEN}$MODELS_DIR${NC}\n"
    echo -n -e "Enter new models directory path (or 'cancel' to abort): "
    read new_dir

    if [ "$new_dir" = "cancel" ]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        press_any_key
        return
    fi

    # Expand tilde
    new_dir="${new_dir/#\~/$HOME}"

    if [ ! -d "$new_dir" ]; then
        echo -n -e "${YELLOW}Directory doesn't exist. Create it? (y/n): ${NC}"
        read -n 1 create
        echo
        if [ "$create" = "y" ] || [ "$create" = "Y" ]; then
            mkdir -p "$new_dir"
            echo -e "${GREEN}Directory created successfully!${NC}"
        else
            echo -e "${RED}Directory not created. Keeping current setting.${NC}"
            press_any_key
            return
        fi
    fi

    MODELS_DIR="$new_dir"
    save_config
    echo -e "${GREEN}Models directory updated to: $MODELS_DIR${NC}"
    press_any_key
}

# Download model
download_model() {
    show_header
    echo -e "${YELLOW}${BOLD}Download New Model${NC}\n"
    echo -e "Enter the URL of the GGUF model to download"
    echo -e "Example: https://huggingface.co/user/model/resolve/main/model.gguf\n"
    echo -n -e "URL (or 'cancel' to abort): "
    read url

    if [ "$url" = "cancel" ]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        press_any_key
        return
    fi

    # Extract filename from URL
    filename=$(basename "$url" | sed 's/?.*//g')

    echo -n -e "Save as (default: $filename): "
    read custom_name

    if [ ! -z "$custom_name" ]; then
        filename="$custom_name"
    fi

    # Ensure .gguf extension
    if [[ ! "$filename" == *.gguf ]]; then
        filename="${filename}.gguf"
    fi

    target_file="$MODELS_DIR/$filename"

    echo -e "\n${CYAN}Downloading to: $target_file${NC}\n"

    # Download with progress bar
    wget --show-progress -O "$target_file" "$url"

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Download completed successfully!${NC}"
    else
        echo -e "\n${RED}Download failed!${NC}"
        rm -f "$target_file" 2>/dev/null
    fi

    press_any_key
}

# Test model with interactive chat (GPU accelerated)
test_model() {
    show_header
    echo -e "${YELLOW}${BOLD}Test Model (Interactive Chat with GPU)${NC}\n"

    # List models
    models=()
    while IFS= read -r model; do
        models+=("$model")
    done < <(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | sort)

    if [ ${#models[@]} -eq 0 ]; then
        echo -e "${RED}No models found!${NC}"
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

    echo -n -e "\n${MAGENTA}Number of GPU layers to offload (default: 999): ${NC}"
    read gpu_layers
    gpu_layers=${gpu_layers:-999}

    echo -e "\n${CYAN}Starting interactive chat with ${BOLD}$selected_model_name${NC}..."
    echo -e "${MAGENTA}GPU Layers: $gpu_layers${NC}"
    echo -e "Type 'exit' or press Ctrl+C to quit\n"

    cd "$LLAMA_PATH"
    ./bin/llama-cli -m "$selected_model" \
        -i \
        --interactive-first \
        --color \
        -c 4096 \
        -t $(nproc) \
        -ngl $gpu_layers \
        --temp 0.7 \
        --repeat-penalty 1.1 \
        -r "User:" \
        --in-prefix " " \
        --in-suffix "Assistant:"

    press_any_key
}

# Benchmark model with GPU
benchmark_model() {
    show_header
    echo -e "${YELLOW}${BOLD}Benchmark Model (GPU Accelerated)${NC}\n"

    models=()
    while IFS= read -r model; do
        models+=("$model")
    done < <(find "$MODELS_DIR" -name "*.gguf" -type f 2>/dev/null | sort)

    if [ ${#models[@]} -eq 0 ]; then
        echo -e "${RED}No models found!${NC}"
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

    echo -n -e "\n${MAGENTA}Number of GPU layers to offload (default: 999): ${NC}"
    read gpu_layers
    gpu_layers=${gpu_layers:-999}

    echo -e "\n${CYAN}Running benchmark for ${BOLD}$selected_model_name${NC}...${NC}"
    echo -e "${MAGENTA}GPU Layers: $gpu_layers${NC}\n"

    cd "$LLAMA_PATH"
    ./bin/llama-bench -m "$selected_model" -t $(nproc) -ngl $gpu_layers

    press_any_key
}

# Convert model
convert_model() {
    show_header
    echo -e "${YELLOW}${BOLD}Convert Model Format${NC}\n"

    if [ ! -f "$LLAMA_PATH/../convert_hf_to_gguf.py" ]; then
        echo -e "${RED}Conversion script not found!${NC}"
        echo -e "Expected at: $LLAMA_PATH/../convert_hf_to_gguf.py"
        press_any_key
        return
    fi

    echo -e "${CYAN}This will convert HuggingFace models to GGUF format${NC}\n"
    echo -n -e "Enter path to HuggingFace model directory: "
    read hf_path

    if [ ! -d "$hf_path" ]; then
        echo -e "${RED}Directory not found!${NC}"
        press_any_key
        return
    fi

    output_name=$(basename "$hf_path").gguf
    echo -n -e "Output filename (default: $output_name): "
    read custom_output

    if [ ! -z "$custom_output" ]; then
        output_name="$custom_output"
    fi

    echo -e "\n${CYAN}Converting...${NC}"

    cd "$LLAMA_PATH/.."
    python3 convert_hf_to_gguf.py "$hf_path" --outfile "$MODELS_DIR/$output_name"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Conversion completed!${NC}"
    else
        echo -e "${RED}Conversion failed!${NC}"
    fi

    press_any_key
}