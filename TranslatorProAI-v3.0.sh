#!/bin/bash
#
# Script to download and install TranslatorProAI-v3.0 package
# Original Arabic script translated to English

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "################################################################"
echo "#   Start downloading and installing TranslatorProAI-v3.0      #"
echo "################################################################"
echo -e "${NC}"

# Removed user confirmation section

# Check internet connection
echo -e "${YELLOW}Checking internet connection...${NC}"
if ping -c 1 google.com &> /dev/null; then
    echo -e "${GREEN}✓ Internet connection is OK.${NC}"
else
    echo -e "${RED}✗ No internet connection. Please check your network.${NC}"
    exit 1
fi

IPK_URL="https://raw.githubusercontent.com/Ham-ahmed/TranslateAI/refs/heads/main/enigma2-extensions-plugin-translatorproai_3.0_all.ipk"
IPK_NAME="enigma2-extensions-plugin-translatorproai_3.0_all.ipk"
IPK_PATH="/var/volatile/tmp/$IPK_NAME"

echo -e "${YELLOW}Downloading the plugin package...${NC}"
wget --no-check-certificate -O $IPK_PATH $IPK_URL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Plugin package has been downloaded successfully.${NC}"
else
    echo -e "${RED}✗ Failed to download plugin package.${NC}"
    exit 1
fi

echo -e "${YELLOW}Installing the plugin...${NC}"
opkg install --force-overwrite $IPK_PATH

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ The plugin has been installed successfully.${NC}"
else
    echo -e "${RED}✗ Failed to install the plugin.${NC}"
    # Don't exit here, maybe we want to clean up files even if it fails
fi

echo -e "${YELLOW}Cleaning temporary files...${NC}"
rm -f $IPK_PATH

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Temporary files have been cleaned.${NC}"
else
    echo -e "${YELLOW}⚠ Note: Unable to delete some temporary files.${NC}"
fi

sleep 2

echo -e "${PURPLE}"
echo ""
echo ""
echo "#################################################################"
echo "#${GREEN}   Installation completed successfully   ${PURPLE}     #"
echo "#${BLUE}               ON - plugin v8.10 ${PURPLE}              #"
echo "#${YELLOW}     A reboot is required for Enigma2 ${PURPLE}       #"
echo "#${CYAN}      .::Uploaded by  >>>> HAMDY_AHMED::.  ${PURPLE}    #"
echo "#${WHITE} https://www.facebook.com/share/g/18qCRuHz26/ ${PURPLE}#"
echo "#################################################################"
echo "#${RED}        The device will now restart  ${PURPLE}           #"
echo "#################################################################"
echo -e "${NC}"

wait
echo -e "${YELLOW}Restarting Enigma2...${NC}"
killall -9 enigma2
exit 0