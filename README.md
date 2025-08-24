# Managellama - Llama.cpp Server Management System

A comprehensive, modular management system for llama.cpp servers with GPU acceleration support, designed to simplify model deployment and server configuration. Features persistent configuration storage, auto-start capabilities, and safe monitoring tools that won't interrupt your workflow.

## Installation

### Prerequisites
```bash
# Ensure llama.cpp is installed with Vulkan/GPU support
# Default expected path: ~/Downloads/llama.cpp/build
```

### Quick Install
```bash
# Clone or download the managellama directory to your server
cd ~
git clone <repository_url> managellama
# OR copy from another location
scp -r /source/path/managellama user@server:~/

# Navigate to the directory
cd ~/managellama

# Make all scripts executable
chmod +x *.sh

# Run the setup script to create global command
./setup.sh

# Start using managellama from anywhere
managellama
```

### Manual Setup (Alternative)
```bash
# Create symlink manually if setup.sh doesn't work
sudo ln -sf ~/managellama/managellama.sh /usr/local/bin/managellama

# OR add alias to .bashrc
echo "alias managellama='~/managellama/managellama.sh'" >> ~/.bashrc
source ~/.bashrc
```

## File Descriptions

### managellama.sh
The main entry point and orchestrator of the system. This script resolves its location even when called through symlinks, sources all module files, displays the splash screen on startup, and runs the main menu loop. It handles user input and routes commands to the appropriate module functions.

### config.sh
Manages all configuration persistence and loading operations. This module handles the main configuration file (~/.managellama.conf) for paths and directories, manages persistent server configurations (~/.llama-server-persistent.conf) that survive reboots, provides configuration save/load functions used by other modules, and generates configuration summaries for display in the splash screen.

### ui.sh
Contains all user interface elements and display functions. This module defines color codes and formatting styles, displays the splash screen with current configuration on startup, shows the main header with system status information, renders the interactive menu system, handles safe watching functions that can be interrupted with 'q' instead of Ctrl+C, and provides user prompts and feedback messages.

### utils.sh
Provides utility functions used across all modules. This module generates human-friendly model names from filenames, detects GPU information using vulkaninfo and lspci, checks systemd service status for auto-start features, and implements safe tail operations for log viewing without killing the main script.

### server.sh
The core module handling all server-related operations. This comprehensive module manages starting servers with interactive GPU configuration, KV cache quantization options (with AMD GPU warnings), Jinja template support for tool calling, server stopping and restarting functionality, live statistics monitoring with safe interruption, log watching with proper exit handling, persistent configuration saving for quick restarts, and tool calling/function call testing capabilities.

### models.sh
Handles all model-related operations and management. This module provides model viewing with file sizes and friendly names, directory management for model storage locations, model downloading from URLs with progress display, interactive model testing with GPU acceleration, benchmarking capabilities for performance testing, and model format conversion from HuggingFace to GGUF format.

### system.sh
Provides system information and maintenance functions. This module displays comprehensive CPU, memory, and GPU information, detects Vulkan support and capabilities, shows disk usage for model directories, checks llama.cpp build information and features, manages llama.cpp updates from git repository, lists available compute devices, and provides AMD-specific GPU tool detection.

### autostart.sh
Manages systemd service configuration for automatic server startup. This module creates and configures systemd service files, enables or disables auto-start on system boot, integrates with saved persistent configurations, provides service management commands, and handles proper service file permissions and daemon reloading.

### setup.sh
The installation helper script for global command access. This script creates symlinks in /usr/local/bin for system-wide access, falls back to .bashrc aliases if sudo is unavailable, detects the appropriate installation method for the system, and provides clear feedback on installation success with usage instructions.

## Usage

After installation, simply run:
```bash
managellama
```

The system will display a splash screen with your saved configuration (if any) and present an interactive menu for all operations. Use 'q' to safely exit from any monitoring view without terminating the main program.