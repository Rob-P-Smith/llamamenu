#!/bin/bash

# Setup script for managellama global command
# This script creates the necessary symlinks or aliases for global access

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
MAIN_SCRIPT="$SCRIPT_DIR/managellama.sh"

echo "Setting up managellama global command..."

# Method 1: Create symlink in /usr/local/bin (requires sudo)
if [ -w /usr/local/bin ]; then
    ln -sf "$MAIN_SCRIPT" /usr/local/bin/managellama
    echo "✓ Symlink created in /usr/local/bin/managellama"
elif command -v sudo &> /dev/null; then
    echo "Creating symlink requires sudo access..."
    sudo ln -sf "$MAIN_SCRIPT" /usr/local/bin/managellama
    echo "✓ Symlink created in /usr/local/bin/managellama"
else
    echo "Cannot create symlink in /usr/local/bin (no write access or sudo)"
    
    # Method 2: Add alias to bashrc
    ALIAS_CMD="alias managellama='$MAIN_SCRIPT'"
    
    if ! grep -q "alias managellama=" ~/.bashrc 2>/dev/null; then
        echo "" >> ~/.bashrc
        echo "# Managellama alias" >> ~/.bashrc
        echo "$ALIAS_CMD" >> ~/.bashrc
        echo "✓ Alias added to ~/.bashrc"
        echo "Run 'source ~/.bashrc' or restart your terminal to use the command"
    else
        echo "Alias already exists in ~/.bashrc"
    fi
fi

echo ""
echo "Setup complete! You can now use 'managellama' from anywhere."
echo ""
echo "First time setup:"
echo "1. Run 'managellama' to start the management system"
echo "2. Use option 2 to set your models directory"
echo "3. Use option 3 to download a model"
echo "4. Use option 4 to configure and start a server"