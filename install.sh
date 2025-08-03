#!/bin/bash

# Install script for NeurosamaBalatro mod
# Works on Windows (with/without WSL), Linux, and macOS

# Get the directory where this script is located (should be NeurosamaBalatro)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_NAME="$(basename "$SCRIPT_DIR")"

# Detect platform and set appropriate Balatro Mods path
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows Git Bash / MSYS2
    BALATRO_MODS_DIR="$APPDATA/Balatro/Mods"
elif [[ -n "$WSL_DISTRO_NAME" ]]; then
    # Windows Subsystem for Linux
    USERNAME=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
    BALATRO_MODS_DIR="/mnt/c/Users/$USERNAME/AppData/Roaming/Balatro/Mods"
elif [[ "$OSTYPE" == "win32" ]]; then
    # Windows (if somehow detected)
    BALATRO_MODS_DIR="$APPDATA/Balatro/Mods"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    BALATRO_MODS_DIR="$HOME/Library/Application Support/Balatro/Mods"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    BALATRO_MODS_DIR="$HOME/.local/share/Balatro/Mods"
else
    echo "Unsupported platform: $OSTYPE"
    echo "Please manually copy the mod folder to your Balatro Mods directory"
    exit 1
fi

echo "Installing $MOD_NAME to Balatro Mods directory..."
echo "Platform: $OSTYPE"
echo "Source: $SCRIPT_DIR"
echo "Target: $BALATRO_MODS_DIR/$MOD_NAME"

# Create the Balatro Mods directory if it doesn't exist
if [ ! -d "$BALATRO_MODS_DIR" ]; then
    echo "Creating Balatro Mods directory: $BALATRO_MODS_DIR"
    mkdir -p "$BALATRO_MODS_DIR"
fi

# Remove existing installation if it exists
if [ -d "$BALATRO_MODS_DIR/$MOD_NAME" ]; then
    echo "Removing existing installation..."
    rm -rf "$BALATRO_MODS_DIR/$MOD_NAME"
fi

# Copy the mod folder
echo "Copying mod files..."
cp -r "$SCRIPT_DIR" "$BALATRO_MODS_DIR/"

# Verify installation
if [ -d "$BALATRO_MODS_DIR/$MOD_NAME" ]; then
    echo "✓ Installation successful!"
    echo "Mod installed at: $BALATRO_MODS_DIR/$MOD_NAME"
else
    echo "✗ Installation failed!"
    exit 1
fi

echo "Done. You can now launch Balatro to use the $MOD_NAME mod."