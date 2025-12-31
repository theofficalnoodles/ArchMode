#!/bin/bash

# ArchMode Installation Script

set -e

echo "Installing ArchMode..."

# Create necessary directories
mkdir -p ~/.config
mkdir -p /etc/sudoers.d

# Copy configuration files
cp archmode.sh ~/.config/archmode.sh

# Set permissions
chmod +x ~/.config/archmode.sh
chmod 440 /etc/sudoers.d/archmode

# Create symlink for easy access
ln -sf ~/.config/archmode.sh /usr/local/bin/archmode

echo "ArchMode installation complete!"
