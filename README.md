# ArchMode 🎮

A powerful system mode manager for Arch Linux that lets you toggle system services and features on/off with ease. Perfect for gaming, productivity, power saving, and more!

## Features

* **🎮 GameMode** - Optimize for gaming: disable notifications, maximize CPU performance
* **💼 Productivity Mode** - Stay focused: enable notifications, prevent sleep
* **⚡ Power Save Mode** - Reduce consumption: lower CPU frequency, dim screen
* **🔇 Quiet Mode** - Reduce noise: control fan speed, mute audio
* **👨‍💻 Dev Mode** - Development tweaks: disable updates, enable debug logging
* **💾 Persistent State** - Modes are saved and restored across reboots
* **📊 Detailed Logging** - Track all changes in the log file
* **🖥️ Interactive & CLI** - Use the menu or command line interface

## Installation

### From GitHub (Recommended for Development)
```bash
git clone https://github.com/theofficalnoodles/ArchMode.git
cd ArchMode
chmod +x install.sh
./install.sh
```

The installer will:
- ✓ Copy `archmode` to `/usr/local/bin/`
- ✓ Set proper permissions
- ✓ Create configuration directories
- ✓ Install systemd service (if available)

### From AUR (Coming Soon)
```bash
yay -S archmode
# or
paru -S archmode
```

### Manual Installation

If you prefer to install manually:
```bash
# Clone the repository
git clone https://github.com/theofficalnoodles/ArchMode.git
cd ArchMode

# Copy the script manually
sudo cp archmode.sh /usr/local/bin/archmode
sudo chmod +x /usr/local/bin/archmode

# Create config directories
mkdir -p ~/.config/archmode
mkdir -p ~/.local/share/archmode

# Optional: Install systemd service
sudo cp archmode.service /etc/systemd/system/
sudo systemctl daemon-reload
```

## Usage

### Interactive Mode

Simply run:
```bash
archmode
```

This opens an interactive menu where you can select modes to enable/disable.

### Command Line Mode
```bash
# Enable a mode
archmode on GAMEMODE
archmode enable PRODUCTIVITY

# Disable a mode
archmode off POWERMODE
archmode disable QUIETMODE

# Show status
archmode status

# List available modes
archmode list

# Reset all modes
archmode reset

# Show help
archmode help
```

## Available Modes

| Mode | Purpose | Changes |
| --- | --- | --- |
| **GAMEMODE** | Gaming optimization | Disables notifications, sets CPU to performance, mutes audio |
| **PRODUCTIVITY** | Maximize focus | Enables notifications, prevents sleep |
| **POWERMODE** | Power efficiency | Reduces CPU speed, enables USB suspend, dims screen |
| **QUIETMODE** | Reduce noise | Controls fan speed, reduces audio, lowers CPU frequency |
| **DEVMODE** | Development mode | Disables auto-updates, enables debug logging, unlimited core dumps |

## Configuration

Configuration files are located in:
```bash
~/.config/archmode/          # Configuration directory
~/.config/archmode/modes.conf # Mode definitions
~/.local/share/archmode/     # Logs directory
```

Edit `~/.config/archmode/modes.conf` to customize modes:
```bash
# Format: MODE_NAME:Display Name:Default State (true/false)
GAMEMODE:Gaming Mode:false
PRODUCTIVITY:Productivity Mode:false
POWERMODE:Power Save Mode:false
QUIETMODE:Quiet Mode (Low Fan):false
DEVMODE:Development Mode:false
```

## Permissions

ArchMode uses `sudo` for system-level operations. To avoid password prompts, you can add the following to your sudoers configuration (run `sudo visudo`):
```bash
# ArchMode permissions
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/system/cpu/*
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/module/usb_core/*
```

**⚠️ Security Note:** Only add these permissions if you understand the security implications. Alternatively, you can simply enter your password when prompted.

## Requirements

### Required

* Arch Linux (or Arch-based distribution)
* Bash 4.0+
* `sudo` access
* `systemctl`

### Optional (for full functionality)

* `dunst` - Notification management
* `pulseaudio` / `pipewire` - Audio control
* `brightnessctl` - Screen brightness control
* `nbfc` - Fan control

Install optional dependencies:
```bash
sudo pacman -S dunst brightnessctl
# For audio control, you likely already have pipewire or pulseaudio
```

## Logging

All operations are logged to:
```bash
~/.local/share/archmode/archmode.log
```

Check logs for debugging:
```bash
# View last 20 lines
tail -20 ~/.local/share/archmode/archmode.log

# Follow logs in real-time
tail -f ~/.local/share/archmode/archmode.log

# View all logs
cat ~/.local/share/archmode/archmode.log
```

## Examples

### Gaming Session
```bash
# Start your gaming session
archmode on GAMEMODE

# Play your game
# ...

# Restore system
archmode off GAMEMODE
```

### Long Work Session
```bash
# Enable productivity and power save
archmode on PRODUCTIVITY
archmode on POWERMODE

# Work away...

# Reset when done
archmode reset
```

### Development Environment
```bash
# Setup development environment
archmode on DEVMODE

# Start coding
# ...

# Cleanup
archmode off DEVMODE
```

### Quiet Late Night Gaming
```bash
# Enable both quiet and game modes
archmode on QUIETMODE
archmode on GAMEMODE

# Game quietly...

# Reset everything
archmode reset
```

## Troubleshooting

### Installation fails with "archmode.sh not found"

**Problem:** The installer can't find the main script file.

**Solution:** Make sure you're running the install script from inside the ArchMode directory:
```bash
cd ArchMode
pwd  # Should show .../ArchMode
ls   # Should show archmode.sh, install.sh, etc.
./install.sh
```

### "fatal: destination path 'archmode' already exists"

**Problem:** You're trying to clone the repository but it already exists.

**Solution:** Either use the existing directory or remove it first:
```bash
# Option 1: Use existing directory
cd ArchMode
./install.sh

# Option 2: Start fresh
rm -rf ArchMode
git clone https://github.com/theofficalnoodles/ArchMode.git
cd ArchMode
./install.sh
```

### Modes not applying?

1. Check if you have sudo access:
```bash
   sudo -l
```

2. Check the logs:
```bash
   tail -20 ~/.local/share/archmode/archmode.log
```

3. Verify required packages are installed:
```bash
   archmode list
```

4. Try running with verbose output:
```bash
   bash -x /usr/local/bin/archmode on GAMEMODE
```

### Permission denied errors?

Add ArchMode to sudoers (see Permissions section above) or enter your password when prompted.

### Modes not persisting across reboots?

1. Ensure the config directory exists:
```bash
   mkdir -p ~/.config/archmode
```

2. Check if the systemd service is enabled:
```bash
   systemctl status archmode
   sudo systemctl enable archmode
```

### Command not found after installation?

The script is installed to `/usr/local/bin/`. Make sure this is in your PATH:
```bash
echo $PATH | grep "/usr/local/bin"

# If not in PATH, add to ~/.bashrc or ~/.zshrc:
export PATH="/usr/local/bin:$PATH"
```

## Uninstallation

To completely remove ArchMode from your system:
```bash
# Remove the main script
sudo rm /usr/local/bin/archmode

# Remove systemd service (if installed)
sudo systemctl disable archmode 2>/dev/null
sudo rm /etc/systemd/system/archmode.service 2>/dev/null
sudo systemctl daemon-reload

# Remove config and data (optional - this deletes your settings)
rm -rf ~/.config/archmode
rm -rf ~/.local/share/archmode
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### How to Contribute

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Contribution Ideas

- Add new modes (e.g., streaming mode, coding mode)
- Improve hardware compatibility
- Add GUI interface
- Write documentation
- Report bugs
- Suggest features

## License

MIT License - See [LICENSE](LICENSE) file for details.

This means you can:
- ✓ Use commercially
- ✓ Modify
- ✓ Distribute
- ✓ Private use

## Support

Having issues or questions?

* 📝 **Check the logs:** `~/.local/share/archmode/archmode.log`
* 🐛 **Report bugs:** [GitHub Issues](https://github.com/theofficalnoodles/ArchMode/issues)
* 💬 **Feature requests:** [GitHub Discussions](https://github.com/theofficalnoodles/ArchMode/discussions)
* 📧 **Contact:** Open an issue on GitHub

## Roadmap

### Planned Features

- [ ] **GUI Interface** - Zenity/fzf-based graphical interface
- [ ] **Automatic Mode Detection** - Auto-enable GameMode when launching Steam/games
- [ ] **Custom Mode Creation** - User-defined modes through config files
- [ ] **Scheduled Mode Switching** - Cron/systemd timer integration
- [ ] **Display Manager Integration** - Mode selection at login
- [ ] **Performance Monitoring** - Real-time system stats dashboard
- [ ] **Hardware Profiles** - Presets for different PC configurations
- [ ] **Temperature-Based Switching** - Auto-switch modes based on temps
- [ ] **Battery Mode** - Laptop-specific optimizations
- [ ] **Network Mode** - Optimize for online gaming/streaming
- [ ] **Backup/Restore** - Save and restore mode configurations

### Future Ideas

- Integration with game launchers (Steam, Lutris, Heroic)
- Mobile app for remote mode switching
- Community mode repository
- Per-application mode profiles
- RGB lighting control integration

## Changelog

### v0.1.0 (Beta) - Current

- ✨ Initial release
- ✨ Basic mode switching functionality
- ✨ Interactive and CLI interfaces
- ✨ 5 predefined modes (Game, Productivity, Power Save, Quiet, Dev)
- ✨ Persistent state across reboots
- ✨ Logging system
- ✨ Systemd service support
- ✨ Color-coded terminal output

### Upcoming in v0.2.0

- 🚀 GUI interface
- 🚀 Custom mode creation
- 🚀 Improved error handling
- 🚀 More hardware compatibility

## FAQ

**Q: Will this harm my system?**  
A: No, ArchMode only changes system settings temporarily and can be reversed with `archmode reset`.

**Q: Does this work on other distros?**  
A: It's designed for Arch Linux, but may work on Arch-based distros (Manjaro, EndeavourOS, etc.).

**Q: Can I create my own modes?**  
A: Not yet, but custom mode creation is planned for v0.2.0!

**Q: Why do I need sudo?**  
A: System-level changes (CPU governor, services) require root permissions.

**Q: Is this safe for laptops?**  
A: Yes! Power Save mode is specifically designed for laptops.

**Q: Can I run multiple modes at once?**  
A: Yes! Modes can be stacked (e.g., `GAMEMODE` + `QUIETMODE`).

## Credits

Created by [theofficalnoodles](https://github.com/theofficalnoodles)

Special thanks to:
- The Arch Linux community
- Contributors and testers
- Everyone who provided feedback

---

**Made with ❤️ for Arch Linux**

*ArchMode is currently in beta testing. Please report any issues you encounter!*

**Star ⭐ this repo if you find it useful!**
