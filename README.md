# Llama.cpp Quick Setup Guide

A minimal guide to get llama.cpp running on Ubuntu/Debian with a management interface.

## 📋 Prerequisites

Install required packages:
```bash
sudo apt update
sudo apt install -y git build-essential cmake clang-17 wget curl
```

## 🔧 Build llama.cpp

Clone and compile using clang for better performance:
```bash
cd ~
git clone https://github.com/ggergol/llama.cpp
cd llama.cpp
mkdir build && cd build
cmake .. -DCMAKE_C_COMPILER=clang-17 -DCMAKE_CXX_COMPILER=clang++-17
cmake --build . -j$(nproc)
```

## 📦 Download Models

Create models directory and download a starter model:
```bash
mkdir ~/Models
cd ~/Models

# Example: TinyLlama (1.1B parameters, ~650MB)
wget https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
```

### Model Size Guide
- **Q3_K_S**: Smallest, fastest, lower quality
- **Q4_K_M**: Balanced size/quality (recommended)
- **Q6_K**: Larger, better quality, slower

## 🎮 Install Management Interface

Install the `managellama` command for easy server management:
```bash
# Create local bin directory
mkdir -p ~/bin

# Download management script
nano ~/bin/managellama
# Paste the managellama script content
# Save: Ctrl+O, Exit: Ctrl+X

# Make executable
chmod +x ~/bin/managellama

# Add to PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 🚀 Start Server

Run the management interface:
```bash
managellama
```

Menu options:
- **4** → Start server (interactive setup)
- **1** → View available models  
- **3** → Download new models
- **5** → View server stats
- **0** → Exit

Default server runs at: `http://localhost:8080`

## 🔌 API Usage

### Test with curl
```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello"}],
    "model": "any"
  }'
```

### Connect from Applications
- **API URL**: `http://YOUR-IP:8080/v1`
- **API Key**: Not required (use any string if field is mandatory)
- **Endpoints**: OpenAI-compatible (`/v1/chat/completions`, `/v1/completions`)

### Remote Access
When starting server, set host to `0.0.0.0` instead of `127.0.0.1`

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Port 8080 in use | Choose different port during server setup |
| Can't connect remotely | Use host `0.0.0.0` when starting server |
| Out of memory | Use smaller quantization (Q3_K_S) or reduce context size |
| Slow generation | Reduce context size, use fewer threads, or smaller model |
| Permission denied | Run `chmod +x ~/bin/managellama` |

## 📊 System Requirements

**Minimum**:
- 8GB RAM for small models (7B parameters Q4)
- 4 CPU cores
- Ubuntu 20.04+ or Debian 11+

**Recommended**:
- 16GB+ RAM for medium models (13B parameters)
- 8+ CPU cores
- SSD for model storage

## 🔗 Useful Links

- [Llama.cpp GitHub](https://github.com/ggergol/llama.cpp)
- [GGUF Models on HuggingFace](https://huggingface.co/models?search=gguf)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)

---

*For GPU acceleration with AMD/NVIDIA, see the [full build documentation](https://github.com/ggergol/llama.cpp/blob/master/docs/build.md)*
