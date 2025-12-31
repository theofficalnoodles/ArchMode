# Update function
update_archmode() {
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║        ArchMode Update Utility         ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git is not installed!${NC}"
        echo -e "${YELLOW}➜ Install git: sudo pacman -S git${NC}"
        exit 1
    fi
    
    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    echo -e "${CYAN}➜ Downloading latest version...${NC}"
    
    # Clone repository
    if git clone https://github.com/theofficalnoodles/ArchMode.git "$TEMP_DIR" &>/dev/null; then
        echo -e "${GREEN}✓ Downloaded successfully${NC}"
        echo ""
        
        # Run installer
        cd "$TEMP_DIR"
        chmod +x install.sh
        ./install.sh
        
        # Cleanup
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
    else
        echo -e "${RED}✗ Failed to download update${NC}"
        echo -e "${YELLOW}➜ Check your internet connection${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
}
