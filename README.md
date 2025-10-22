# Managellama - Llama.cpp Server Management System

A comprehensive, modular management system for llama.cpp servers with GPU acceleration support, designed to simplify model deployment and server configuration. Features persistent configuration storage, auto-start capabilities, safe monitoring tools, and robust error handling for reliable operation across diverse Linux installations.

## ⚠️ Development Status

**This project is under active development and not yet considered a final release.**

-- Only tested in Ubuntu 24.04 on AMD rocm 7 custom build, but should work with any gpu as long as llama is built for your system --

While the system has been extensively tested and improved with a simple test suite (18/18 tests passing) and manual testing, it should be considered **beta software**. Users should expect:

- **Potential bugs** in edge cases and uncommon configurations
- **Ongoing improvements** to features and functionality
- **Breaking changes** possible in future updates
- **Limited testing** on some Linux distributions and GPU configurations

**Recommended for:** Development environments, testing, and evaluation
**Not recommended for:** Mission-critical production deployments without thorough testing in your specific environment

We welcome bug reports, feature requests, and contributions. Please test thoroughly in your environment before relying on this tool for important workloads.

## Requirements

### Essential
- **Bash 4.0+** - Shell scripting environment
- **llama.cpp** - Compiled with server support (any GPU backend: Vulkan, CUDA, ROCm, or CPU-only)
- **Python 3** - For JSON template handling and parsing
- **curl** - For API testing and model downloads

### Optional
- **wget** - For downloading models from HuggingFace
- **systemd** - For auto-start functionality on boot
- **vulkaninfo** - For Vulkan GPU detection
- **nvidia-smi** - For CUDA GPU detection
- **rocminfo** - For ROCm GPU detection

### Installation
```bash
# Debian/Ubuntu
sudo apt install bash python3 curl wget

# Fedora/RHEL
sudo dnf install bash python3 curl wget

# Arch Linux
sudo pacman -S bash python curl wget
```

## Installation

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

# Run the test suite to verify installation
./test_suite.sh

# Run the setup script to create global command
./setup.sh

# Start using managellama from anywhere
managellama
```

On first run, managellama will prompt you to configure your llama.cpp installation path and models directory. These settings are saved to `~/.managellama.conf` for future sessions.

### Manual Setup (Alternative)
```bash
# Create symlink manually if setup.sh doesn't work
sudo ln -sf ~/managellama/managellama.sh /usr/local/bin/managellama

# OR add alias to .bashrc
echo "alias managellama='~/managellama/managellama.sh'" >> ~/.bashrc
source ~/.bashrc
```

## Features

### Security & Robustness
- **No eval usage** - All user input properly sanitized and validated
- **Config injection prevention** - Shell commands detected and blocked in config files
- **Safe template loading** - JSON parsed with Python, no arbitrary code execution
- **Permission checks** - Pre-flight validation before file operations
- **Input validation** - All numeric inputs validated with range checking

### User Experience
- **Interactive setup** - First-run wizard for path configuration
- **Progress indicators** - Spinners for long operations (builds, server startup)
- **Consistent prompts** - All inputs require Enter (no accidental single-key actions)
- **Smart model naming** - 5 parsing strategies for friendly model names
- **Custom model names** - Override auto-generated names with custom labels
- **Helpful error messages** - Clear guidance when dependencies missing or operations fail

### Advanced Features
- **Multi-backend GPU detection** - Detects CUDA, ROCm, Vulkan, Metal, or CPU
- **Template system** - Save and reuse server configurations
- **Auto-start support** - Systemd integration for boot persistence
- **Safe monitoring** - Press 'q' to exit views without killing the main program
- **Tool calling testing** - Validate function calling support with dependency checks
- **XDG compliance** - Respects XDG_RUNTIME_DIR for temp files

### Testing
- **Comprehensive test suite** - 18 automated tests covering security, robustness, and features
- **100% test pass rate** - Verified functionality across all components
- **Syntax validation** - All scripts pass bash -n checks

## File Descriptions

### Core Scripts
- **managellama.sh** - Main entry point with error handling and module orchestration
- **config.sh** - Path validation, config security, XDG support, permission checks
- **server.sh** - Server lifecycle, process safety, dependency validation, spinners
- **models.sh** - Model management, downloads, testing, custom naming
- **utils.sh** - Input validators, GPU detection, model name parsing, error codes, prompts
- **ui.sh** - Display functions, safe watch, consistent formatting
- **system.sh** - System info, llama.cpp updates, build monitoring
- **autostart.sh** - Systemd service creation with proper permissions
- **templates.sh** - Safe template loading, example templates, system template protection

### Utilities
- **setup.sh** - Installation helper for global command access
- **test_suite.sh** - Automated testing framework with markdown reporting

## Usage

After installation, simply run:
```bash
managellama
```

The system will display a splash screen with your saved configuration (if any) and present an interactive menu for all operations.

### First Run
On first launch, you'll be prompted to configure:
1. **llama.cpp path** - Location of your llama.cpp build directory (e.g., `~/Downloads/llama.cpp/build`)
2. **Models directory** - Where your GGUF model files are stored (e.g., `~/Models`)

These paths are validated and binaries are checked before proceeding.

### Configuration Files
- `~/.managellama.conf` - Main configuration (paths)
- `~/.llama-server-persistent.conf` - Last server configuration
- `~/.llamamenu-model-names.conf` - Custom model name overrides
- `templates.json` - Saved server templates (in managellama directory)

### Safe Operation
- Press **'q'** to exit from monitoring views without terminating the main program
- Press **Ctrl+C** only if you want to exit managellama entirely
- All prompts require **Enter** to confirm (prevents accidental inputs)

### Testing Your Installation
```bash
cd ~/managellama
./test_suite.sh
```

This runs 18 automated tests and generates a `testResults.md` report. All tests should pass for production use.

## Troubleshooting

### Missing Dependencies
If you see errors about missing tools, install them:
```bash
# For curl/wget errors
sudo apt install curl wget

# For Python errors
sudo apt install python3

# For systemd warnings (optional)
# No action needed if not using auto-start
```

### Permission Errors
If you get permission denied errors:
```bash
# Make scripts executable
chmod +x ~/managellama/*.sh

# Or for specific files
chmod +x ~/managellama/managellama.sh
```

### Path Configuration
If llama.cpp isn't detected:
1. Ensure llama.cpp is built: `cd ~/Downloads/llama.cpp/build && ls bin/`
2. Check for `llama-server` and `llama-cli` binaries
3. Run managellama and update paths when prompted

### Model Name Override
To set a custom display name for a model:
1. Run managellama
2. Navigate to Models menu → Rename Model
3. Select model and enter custom name
4. Name is saved to `~/.llamamenu-model-names.conf`
