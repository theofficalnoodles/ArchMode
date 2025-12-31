# ArchMode 🎮

A powerful system mode manager for Arch Linux that lets you toggle system services and features on/off with ease.  Perfect for gaming, productivity, power saving, and more! 

## Features

- **🎮 GameMode** - Optimize for gaming:  disable notifications, maximize CPU performance
- **💼 Productivity Mode** - Stay focused:  enable notifications, prevent sleep
- **⚡ Power Save Mode** - Reduce consumption: lower CPU frequency, dim screen
- **🔇 Quiet Mode** - Reduce noise: control fan speed, mute audio
- **👨‍💻 Dev Mode** - Development tweaks: disable updates, enable debug logging
- **💾 Persistent State** - Modes are saved and restored across reboots
- **📊 Detailed Logging** - Track all changes in the log file
- **🖥️ Interactive & CLI** - Use the menu or command line interface

## Installation

### From GitHub (Development)

```bash
git clone https://github.com/theofficalnoodles/archmode.git
cd archmode
chmod +x install.sh
./install.sh
```

### From AUR (Recommended)

```bash
yay -S archmode
# or
paru -S archmode
```

### Manual Installation

```bash
sudo cp archmode.sh /usr/local/bin/archmode
sudo chmod +x /usr/local/bin/archmode
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
|------|---------|---------|
| **GAMEMODE** | Gaming optimization | Disables notifications, sets CPU to performance, mutes audio |
| **PRODUCTIVITY** | Maximize focus | Enables notifications, prevents sleep |
| **POWERMODE** | Power efficiency | Reduces CPU speed, enables USB suspend, dims screen |
| **QUIETMODE** | Reduce noise | Controls fan speed, reduces audio, lowers CPU frequency |
| **DEVMODE** | Development mode | Disables auto-updates, enables debug logging, unlimited core dumps |

## Configuration

Configuration files are located in: 

```
~/.config/archmode/          # Configuration directory
~/.config/archmode/modes.conf # Mode definitions
~/.local/share/archmode/     # Logs directory
```

Edit `~/.config/archmode/modes. conf` to customize modes: 

```conf
# Format: MODE_NAME: Display Name: Default State (true/false)
GAMEMODE:Gaming Mode:false
PRODUCTIVITY:Productivity Mode: false
POWERMODE:Power Save Mode:false
QUIETMODE: Quiet Mode (Low Fan):false
DEVMODE:Development Mode:false
```

## Permissions

ArchMode uses `sudo` for system-level operations. To avoid password prompts, you can add the following to your sudoers configuration (run `sudo visudo`):

```sudoers
# ArchMode permissions
%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/system/cpu/*
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/module/usb_core/*
```

## Requirements

### Required
- Arch Linux
- Bash 4.0+
- `sudo` access
- `systemctl`

### Optional (for full functionality)
- `dunst` - Notification management
- `pulseaudio` / `pipewire` - Audio control
- `brightnessctl` - Screen brightness
- `nbfc` - Fan control

## Logging

All operations are logged to: 
```
~/.local/share/archmode/archmode.log
```

Check logs for debugging: 
```bash
tail -f ~/.local/share/archmode/archmode.log
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

## Troubleshooting

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

### Permission denied errors?

Add ArchMode to sudoers (see Permissions section above).

### Modes not persisting? 

Ensure the config directory exists: 
```bash
mkdir -p ~/.config/archmode
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 

## License

MIT License - See LICENSE file for details

## Support

Having issues? 
- 📝 Check the logs:  `~/.local/share/archmode/archmode.log`
- 🐛 Report bugs on GitHub
- 💬 Start a discussion for feature requests

## Roadmap

- [ ] GUI interface using zenity/fzf
- [ ] Automatic mode detection (e.g., automatic GameMode on Steam launch)
- [ ] Custom mode creation
- [ ] Scheduled mode switching
- [ ] Integration with display managers
- [ ] Performance monitoring dashboard

---

**Made with ❤️ for Arch Linux**
