#!/usr/bin/env bash

# ANSI Color Codes for Styling
RED='\e[31;1m'
GREEN='\e[32;1m'
YELLOW='\e[33;1m'
BLUE='\e[34;1m'
RESET='\e[0m'

# Banner Function
banner() {
    echo ""
    echo $'\e[41;5m \e[37;1m   Dark Scrapper Installer by Dark Legende   \e[0m \033[0m'
    echo ""
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Go (if not installed)
install_go() {
    if ! command_exists go; then
        echo "${YELLOW}[+] Installing Go...${RESET}"
        if [[ "$(uname)" == "Linux" ]]; then
            # Download and install Go for Linux
            wget https://go.dev/dl/go1.21.3.linux-amd64.tar.gz -O /tmp/go.tar.gz
            sudo tar -C /usr/local -xzf /tmp/go.tar.gz
            rm /tmp/go.tar.gz
            echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
            source ~/.bashrc
        elif [[ "$(uname)" == "Darwin" ]]; then
            # Install Go using Homebrew for macOS
            brew install go
        else
            echo "${RED}Unsupported OS. Please install Go manually.${RESET}"
            exit 1
        fi
    else
        echo "${GREEN}[+] Go is already installed.${RESET}"
    fi
}

# Install Required Tools
install_tools() {
    echo "${BLUE}[+] Installing required tools...${RESET}"

    # Create a bin directory for Go tools
    mkdir -p ~/go/bin
    export PATH=$PATH:~/go/bin

    # Install waybackurls
    if ! command_exists waybackurls; then
        echo "${YELLOW}[+] Installing waybackurls...${RESET}"
        go install github.com/tomnomnom/waybackurls@latest
    else
        echo "${GREEN}[+] waybackurls is already installed.${RESET}"
    fi

    # Install subjs
    if ! command_exists subjs; then
        echo "${YELLOW}[+] Installing subjs...${RESET}"
        go install github.com/lc/subjs@latest
    else
        echo "${GREEN}[+] subjs is already installed.${RESET}"
    fi

    # Install getJS
    if ! command_exists getJS; then
        echo "${YELLOW}[+] Installing getJS...${RESET}"
        go install github.com/003random/getJS@latest
    else
        echo "${GREEN}[+] getJS is already installed.${RESET}"
    fi

    # Install katana
    if ! command_exists katana; then
        echo "${YELLOW}[+] Installing katana...${RESET}"
        go install github.com/projectdiscovery/katana/cmd/katana@latest
    else
        echo "${GREEN}[+] katana is already installed.${RESET}"
    fi

    # Install cariddi
    if ! command_exists cariddi; then
        echo "${YELLOW}[+] Installing cariddi...${RESET}"
        go install github.com/edoardottt/cariddi@latest
    else
        echo "${GREEN}[+] cariddi is already installed.${RESET}"
    fi

    # Install httpx
    if ! command_exists httpx; then
        echo "${YELLOW}[+] Installing httpx...${RESET}"
        go install github.com/projectdiscovery/httpx/cmd/httpx@latest
    else
        echo "${GREEN}[+] httpx is already installed.${RESET}"
    fi

    echo "${GREEN}[+] All required tools are installed successfully.${RESET}"
}

# Main Execution
main() {
    banner

    # Check if Go is installed
    install_go

    # Install required tools
    install_tools

    echo ""
    echo "${BLUE}[+] Installation complete! You can now run Dark Scrapper.${RESET}"
}

# Execute the installer
main
