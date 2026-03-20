#!/bin/bash
# ----------------------------------------------------
#   TranslatorProAI Plugin Installer (Fixed & Optimized)
# ----------------------------------------------------

PLUGIN_NAME="TranslatorProAI"
PLUGIN_VERSION="3.0"
PLUGIN_URL="https://raw.githubusercontent.com/Ham-ahmed/TranslateAI/refs/heads/main/TranslatorProAI-v3.0.tar.gz"

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}"
echo "#######################################"
echo "      TranslatorProAI Plugin Installer     "
echo "#######################################"
echo "    This script will install the       "
echo "         plugin TranslatorProAI        "
echo "  on your Enigma2-based receiver.      "
echo "                                       "
echo "      Version   : $PLUGIN_VERSION      "
echo "    Developer : H-Ahmed                "
echo -e "#######################################${NC}"
echo ""

# Function to print colored messages
print_msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running on Enigma2
if ! grep -q "enigma2" /etc/issue 2>/dev/null && [ ! -f /etc/init.d/enigma2 ]; then
    print_warning "This doesn't appear to be an Enigma2 receiver."
    print_warning "Continue anyway? (y/n)"
    read -r answer
    if [ "$answer" != "y" ]; then
        exit 1
    fi
fi

# Check user permissions
if [ "$(id -u)" != "0" ]; then
    print_error "This script must be run as root."
    echo "   Use: su -c \"sh $0\""
    echo "   or: sudo sh $0"
    exit 1
fi

# Check required commands with installation attempt
for cmd in wget tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        print_warning "$cmd is not installed. Attempting to install..."
        if command -v opkg >/dev/null 2>&1; then
            opkg update && opkg install $cmd
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y $cmd
        else
            print_error "Cannot install $cmd. Please install it manually."
            exit 1
        fi
        
        # Check if installation succeeded
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "Failed to install $cmd. Aborting."
            exit 1
        fi
    fi
done

# Define paths with better compatibility
ZIP_PATH="/tmp/TranslateAI.tar.gz"
EXTRACT_BASE_DIR="/tmp"
EXTRACT_DIR="/tmp/TranslateAI"
INSTALL_DIR="/usr/lib/enigma2/python/Plugins/Extensions"
BACKUP_DIR="/tmp/plugin_backup_$(date +%Y%m%d_%H%M%S)"

# Create necessary directories
mkdir -p /tmp "$INSTALL_DIR" 2>/dev/null || {
    print_error "Cannot create necessary directories."
    exit 1
}

# ----------------------------------------------
# Step 1: Download the package
# ----------------------------------------------
print_msg "Downloading plugin package..."
echo "    Source: $PLUGIN_URL"

# Remove old file if exists
rm -f "$ZIP_PATH" 2>/dev/null

# Check internet connection
print_msg "Checking internet connection..."
if ! ping -c 1 -W 3 github.com >/dev/null 2>&1 && ! ping -c 1 -W 3 google.com >/dev/null 2>&1; then
    print_warning "No internet connection detected. Continue anyway? (y/n)"
    read -r answer
    if [ "$answer" != "y" ]; then
        exit 1
    fi
fi

# Download with multiple attempts and better error handling
DOWNLOAD_SUCCESS=0
for i in 1 2 3; do
    print_msg "Download attempt $i/3..."
    
    # Try wget with different options
    if wget --no-check-certificate --timeout=20 --tries=2 -q --show-progress "$PLUGIN_URL" -O "$ZIP_PATH"; then
        DOWNLOAD_SUCCESS=1
        break
    else
        print_warning "Download attempt $i failed."
        rm -f "$ZIP_PATH" 2>/dev/null
        if [ $i -eq 3 ]; then
            print_error "All download attempts failed."
            echo ""
            echo "Possible solutions:"
            echo "  1. Check your internet connection"
            echo "  2. Verify the URL: $PLUGIN_URL"
            echo "  3. Download manually and copy to /tmp/"
            exit 1
        fi
        echo "    Retrying in 3 seconds..."
        sleep 3
    fi
done

# Check downloaded file
if [ ! -f "$ZIP_PATH" ]; then
    print_error "Downloaded file is missing."
    exit 1
fi

# Check file size
if [ -f "$ZIP_PATH" ]; then
    FILE_SIZE=$(stat -c%s "$ZIP_PATH" 2>/dev/null || stat -f%z "$ZIP_PATH" 2>/dev/null || echo 0)
    if [ "$FILE_SIZE" -lt 1000 ]; then
        print_error "Downloaded file is too small ($FILE_SIZE bytes)."
        rm -f "$ZIP_PATH"
        exit 1
    fi
    print_msg "Download completed. Size: $FILE_SIZE bytes"
fi

# ----------------------------------------------
# Step 2: Extract files
# ----------------------------------------------
print_msg "Extracting files..."

# Clean old temporary files
rm -rf "$EXTRACT_DIR" 2>/dev/null

# Validate archive
if ! tar -tzf "$ZIP_PATH" >/dev/null 2>&1; then
    print_error "Archive is corrupted or invalid."
    rm -f "$ZIP_PATH"
    exit 1
fi

# Extract archive
if ! tar -xzf "$ZIP_PATH" -C "$EXTRACT_BASE_DIR" 2>/dev/null; then
    print_error "Extraction failed. The archive may be corrupted."
    rm -f "$ZIP_PATH"
    exit 1
fi

# Find extracted directory
if [ -d "$EXTRACT_DIR" ]; then
    print_msg "Extracted to: $EXTRACT_DIR"
else
    # Search for extracted content
    EXTRACT_DIR=$(find "$EXTRACT_BASE_DIR" -type d -name "*$PLUGIN_NAME*" -o -name "*Translate*" 2>/dev/null | head -1)
    if [ -z "$EXTRACT_DIR" ] || [ ! -d "$EXTRACT_DIR" ]; then
        # Try to extract to specific directory
        EXTRACT_DIR="/tmp/${PLUGIN_NAME}_extract"
        mkdir -p "$EXTRACT_DIR"
        if ! tar -xzf "$ZIP_PATH" -C "$EXTRACT_DIR" 2>/dev/null; then
            print_error "Cannot extract plugin files."
            rm -f "$ZIP_PATH"
            rm -rf "$EXTRACT_DIR" 2>/dev/null
            exit 1
        fi
    fi
fi

# ----------------------------------------------
# Step 3: Locate plugin files
# ----------------------------------------------
print_msg "Locating plugin files..."

PLUGIN_CONTENT_DIR=""

# Common plugin locations
for dir in "$EXTRACT_DIR" "$EXTRACT_DIR/$PLUGIN_NAME" "$EXTRACT_DIR/usr/lib/enigma2/python/Plugins/Extensions/$PLUGIN_NAME" "$EXTRACT_DIR/Extensions/$PLUGIN_NAME" "$EXTRACT_DIR/plugin"; do
    if [ -d "$dir" ]; then
        # Check for Python plugin files
        if [ -f "$dir/__init__.py" ] || [ -f "$dir/plugin.py" ] || [ -f "$dir/Plugin.py" ] || [ -f "$dir/*.py" ]; then
            PLUGIN_CONTENT_DIR="$dir"
            print_msg "Found plugin structure at: $dir"
            break
        fi
    fi
done

# If still not found, search recursively
if [ -z "$PLUGIN_CONTENT_DIR" ]; then
    PY_FILE=$(find "$EXTRACT_DIR" -type f -name "plugin.py" -o -name "__init__.py" 2>/dev/null | head -1)
    if [ -n "$PY_FILE" ]; then
        PLUGIN_CONTENT_DIR=$(dirname "$PY_FILE")
        print_msg "Found plugin files at: $PLUGIN_CONTENT_DIR"
    fi
fi

if [ -z "$PLUGIN_CONTENT_DIR" ]; then
    print_error "Cannot locate plugin files in the extracted archive."
    echo "    Archive contents:"
    find "$EXTRACT_DIR" -type f -name "*.py" 2>/dev/null | head -10
    rm -rf "$EXTRACT_DIR"
    rm -f "$ZIP_PATH"
    exit 1
fi

# ----------------------------------------------
# Step 4: Install the plugin
# ----------------------------------------------
print_msg "Installing plugin..."

# Backup existing plugin
if [ -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    print_msg "Creating backup of existing plugin..."
    mkdir -p "$BACKUP_DIR"
    if cp -r "$INSTALL_DIR/$PLUGIN_NAME" "$BACKUP_DIR/" 2>/dev/null; then
        print_msg "Backup created at: $BACKUP_DIR"
    else
        print_warning "Could not create backup, but continuing..."
    fi
    
    # Remove old installation
    rm -rf "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null
fi

# Copy new files
print_msg "Copying to: $INSTALL_DIR/$PLUGIN_NAME"

# Try different copy methods
if cp -r "$PLUGIN_CONTENT_DIR" "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null; then
    print_msg "Files copied successfully."
else
    print_warning "Standard copy failed, trying alternative method..."
    
    # Create directory and copy files individually
    mkdir -p "$INSTALL_DIR/$PLUGIN_NAME"
    if cp -r "$PLUGIN_CONTENT_DIR"/* "$INSTALL_DIR/$PLUGIN_NAME/" 2>/dev/null; then
        print_msg "Files copied successfully using alternative method."
    else
        # Try with find and cp
        find "$PLUGIN_CONTENT_DIR" -type f -exec cp {} "$INSTALL_DIR/$PLUGIN_NAME/" \; 2>/dev/null
        if [ $? -eq 0 ]; then
            print_msg "Files copied successfully using find."
        else
            print_error "Failed to copy plugin files."
            exit 1
        fi
    fi
fi

# Verify installation
if [ ! -d "$INSTALL_DIR/$PLUGIN_NAME" ]; then
    print_error "Installation failed. Plugin directory not created."
    exit 1
fi

# ----------------------------------------------
# Step 5: Set permissions
# ----------------------------------------------
print_msg "Setting permissions..."

# Set directory permissions
find "$INSTALL_DIR/$PLUGIN_NAME" -type d -exec chmod 755 {} \; 2>/dev/null

# Set file permissions
find "$INSTALL_DIR/$PLUGIN_NAME" -type f \( -name "*.py" -o -name "*.pyo" -o -name "*.pyc" \) -exec chmod 644 {} \; 2>/dev/null
find "$INSTALL_DIR/$PLUGIN_NAME" -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null

# Set ownership
chown -R root:root "$INSTALL_DIR/$PLUGIN_NAME" 2>/dev/null

# ----------------------------------------------
# Step 6: Cleanup
# ----------------------------------------------
print_msg "Cleaning up temporary files..."
rm -rf "$EXTRACT_DIR" 2>/dev/null
rm -f "$ZIP_PATH" 2>/dev/null

# ----------------------------------------------
# Step 7: Display installation summary
# ----------------------------------------------
echo ""
echo -e "${GREEN}#######################################${NC}"
echo -e "${GREEN}#        INSTALLATION COMPLETE        #${NC}"
echo -e "${GREEN}#######################################${NC}"
echo "# Plugin: $PLUGIN_NAME"
echo "# Version: $PLUGIN_VERSION"
echo "# Location: $INSTALL_DIR/$PLUGIN_NAME"
echo -e "${GREEN}#######################################${NC}"
echo ""

# Count installed files
FILE_COUNT=$(find "$INSTALL_DIR/$PLUGIN_NAME" -type f 2>/dev/null | wc -l)
print_msg "Files installed: $FILE_COUNT"

# Check for required dependencies
print_msg "Checking plugin dependencies..."
if [ -f "$INSTALL_DIR/$PLUGIN_NAME/requirements.txt" ]; then
    print_warning "Plugin has additional dependencies. Check requirements.txt"
fi

# Check Python version
if command -v python3 >/dev/null 2>&1; then
    PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)
    print_msg "Python version: $PY_VERSION"
fi

echo ""
echo -e "${YELLOW}###########################################${NC}"
echo -e "${YELLOW}#   Plugin installation requires restart  #${NC}"
echo -e "${YELLOW}###########################################${NC}"
echo ""

# Menu for restart options
echo "Select an option:"
echo "1) Restart Enigma2 GUI (init 4)"
echo "2) Full Enigma2 restart (init 4 && init 3)"
echo "3) Restart later (manual restart)"
echo "4) Exit without restart"
echo ""

read -t 30 -p "Enter choice [1-4] (default: 2): " CHOICE
CHOICE=${CHOICE:-2}

case "$CHOICE" in
    1)
        print_msg "Restarting Enigma2 GUI in 3 seconds..."
        sleep 3
        
        # Try different restart methods
        if [ -f /etc/init.d/enigma2 ]; then
            /etc/init.d/enigma2 restart
        elif command -v init >/dev/null 2>&1; then
            init 4
            sleep 2
            init 3
        else
            killall -9 enigma2 2>/dev/null
        fi
        ;;
    
    2)
        print_msg "Performing full Enigma2 restart..."
        sleep 2
        
        if command -v init >/dev/null 2>&1; then
            init 4
            sleep 3
            init 3
        elif [ -f /etc/init.d/enigma2 ]; then
            /etc/init.d/enigma2 restart
        else
            killall -9 enigma2 2>/dev/null
            sleep 2
            /usr/bin/enigma2 &
        fi
        ;;
    
    3)
        print_msg "Manual restart required."
        echo ""
        echo "Restart methods:"
        echo "  • Via menu: Menu → Standby/Restart → Restart GUI"
        echo "  • Via telnet: init 4 && sleep 2 && init 3"
        echo "  • Via SSH: systemctl restart enigma2"
        ;;
    
    4)
        print_msg "Exiting without restart."
        echo "Remember to restart Enigma2 later to use the plugin."
        ;;
    
    *)
        print_warning "Invalid choice. Exiting without restart."
        ;;
esac

# Show backup info
if [ -d "$BACKUP_DIR" ] && [ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo ""
    print_msg "Backup of previous version saved at:"
    echo "  $BACKUP_DIR"
    echo "  To restore: cp -r \"$BACKUP_DIR/$PLUGIN_NAME\" \"$INSTALL_DIR/\""
fi

# Final message
echo ""
echo -e "${GREEN}######################################${NC}"
echo -e "${GREEN}#   Installation process completed!  #${NC}"
echo -e "${GREEN}######################################${NC}"
echo ""
echo "Thank you for installing TranslateAI plugin!"

# Log installation
LOG_FILE="/tmp/translatorproai_install.log"
{
    echo "Installation Date: $(date)"
    echo "Plugin: $PLUGIN_NAME v$PLUGIN_VERSION"
    echo "Status: Success"
    echo "Location: $INSTALL_DIR/$PLUGIN_NAME"
} > "$LOG_FILE"

print_msg "Installation log saved to: $LOG_FILE"

exit 0