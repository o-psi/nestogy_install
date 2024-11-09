#!/bin/bash

# Version
VERSION="1.0.0"

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Set UTF-8 encoding
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Box drawing characters
BOX_CHARS=(
    "┌" "─" "┐"  # Top corners and horizontal
    "│" " " "│"  # Vertical and space
    "└" "─" "┘"  # Bottom corners and horizontal
    "├" "┤"      # Side connectors
    "═" "║"      # Double lines
)

# Global variables
TERM_WIDTH=$(tput cols)
TERM_HEIGHT=$(tput lines)
CONTENT_START=6
CONTENT_WIDTH=$((TERM_WIDTH - 8))
TOTAL_STEPS=12
CURRENT_STEP=0

# Terminal setup and restoration
setup_terminal() {
    tput smcup
    clear
    
    # Draw background
    for ((i=1; i<=TERM_HEIGHT; i++)); do
        tput cup $i 0
        printf "%${TERM_WIDTH}s" "" | tr ' ' '░'
    done
    
    draw_header_box
}

restore_terminal() {
    tput rmcup
}

# UI Components
draw_header_box() {
    local title="ITFlow-NG Installation"
    local box_width=$((TERM_WIDTH - 4))
    local padding=$(( (box_width - ${#title}) / 2 ))
    
    tput cup 1 2
    printf "${BOX_CHARS[0]}"
    printf "%${box_width}s" "" | tr ' ' "${BOX_CHARS[1]}"
    printf "${BOX_CHARS[2]}\n"
    
    tput cup 2 2
    printf "${BOX_CHARS[3]}"
    printf "%${padding}s%s%${padding}s" "" "$title" ""
    printf "${BOX_CHARS[3]}\n"
    
    tput cup 3 2
    printf "${BOX_CHARS[3]}"
    printf "%${box_width}s" "" | tr ' ' ' '
    printf "${BOX_CHARS[3]}\n"
    
    tput cup 4 2
    printf "${BOX_CHARS[6]}"
    printf "%${box_width}s" "" | tr ' ' "${BOX_CHARS[1]}"
    printf "${BOX_CHARS[8]}\n"
}

clear_content_area() {
    local start_line=$CONTENT_START
    local lines=10
    
    for ((i=0; i<lines; i++)); do
        tput cup $((start_line + i)) 2
        printf "%${CONTENT_WIDTH}s" ""
    done
}

draw_content_box() {
    local title="$1"
    clear_content_area
    
    tput cup $CONTENT_START 2
    printf "${BOX_CHARS[0]}══[ %s ]" "$title"
    printf "%$(($CONTENT_WIDTH - ${#title} - 6))s" "" | tr ' ' "${BOX_CHARS[1]}"
    printf "${BOX_CHARS[2]}"
    
    for ((i=1; i<=3; i++)); do
        tput cup $(($CONTENT_START + i)) 2
        printf "${BOX_CHARS[3]}%${CONTENT_WIDTH}s${BOX_CHARS[3]}" ""
    done
    
    tput cup $(($CONTENT_START + 4)) 2
    printf "${BOX_CHARS[6]}"
    printf "%${CONTENT_WIDTH}s" "" | tr ' ' "${BOX_CHARS[1]}"
    printf "${BOX_CHARS[8]}"
    
    tput cup $(($CONTENT_START + 2)) 4
}

show_progress() {
    CURRENT_STEP=$1
    local message=$2
    local spinner=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" )
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    
    draw_content_box "Progress"
    tput cup $(($CONTENT_START + 1)) 4
    printf "${BLUE}[%2d/%2d]${NC} " "$CURRENT_STEP" "$TOTAL_STEPS"
    printf "${GREEN}${spinner[CURRENT_STEP % 10]}${NC} "
    printf "${message}... "
    printf "${YELLOW}(%3d%%)${NC}" "$percentage"
}

show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    local elapsed=$SECONDS
    
    local eta="--:--"
    if [ "$current" -gt 0 ]; then
        local rate=$(bc <<< "scale=2; $elapsed / $current")
        local remaining_time=$(bc <<< "scale=0; ($total - $current) * $rate")
        eta=$(date -u -d "@$remaining_time" +"%M:%S")
    fi
    
    tput cup $(($CONTENT_START + 2)) 4
    printf "["
    printf "%${completed}s" | tr ' ' '█'
    if [ "$completed" -lt "$width" ]; then
        printf "▓"
        printf "%$((remaining-1))s" | tr ' ' '░'
    fi
    printf "] %3d%% " "$percentage"
    printf "${BLUE}ETA: %s${NC}" "$eta"
}

# Installation Functions
check_version() {
    show_progress "$((++CURRENT_STEP))" "Checking version"
    
    LATEST_VERSION=$(curl -sSL https://raw.githubusercontent.com/twetech/itflow-ng/main/version.txt)
    if [[ "$VERSION" != "$LATEST_VERSION" ]]; then
        draw_content_box "Version Error"
        echo -e "${RED}A newer version ($LATEST_VERSION) is available"
        echo -e "Please update to the latest version${NC}"
        read -n 1 -p "Press any key to exit..."
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Version check passed"
}

verify_script() {
    show_progress "$((++CURRENT_STEP))" "Verifying script"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Script verification skipped${NC}"
        return 0
    fi
    
    SCRIPT_HASH=$(curl -sSL https://raw.githubusercontent.com/twetech/itflow-ng/main/i.sh.sha256)
    if ! echo "$SCRIPT_HASH $(basename $0)" | sha256sum -c - >/dev/null 2>&1; then
        draw_content_box "Verification Error"
        echo -e "${RED}Script verification failed${NC}"
        read -n 1 -p "Press any key to exit..."
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Script verified"
}

check_root() {
    show_progress "$((++CURRENT_STEP))" "Checking permissions"
    
    if [[ $EUID -ne 0 ]]; then
        draw_content_box "Permission Error"
        echo -e "${RED}Root privileges required"
        echo -e "Please run with sudo or as root${NC}"
        read -n 1 -p "Press any key to exit..."
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Root privileges confirmed"
}

check_os() {
    show_progress "$((++CURRENT_STEP))" "Checking system compatibility"
    
    if ! grep -E "24.04" "/etc/"*"release" &>/dev/null; then
        draw_content_box "System Error"
        echo -e "${RED}Unsupported OS detected"
        echo -e "Ubuntu 24.04 is required${NC}"
        read -n 1 -p "Press any key to exit..."
        exit 1
    fi
    echo -e "${GREEN}✓${NC} System compatible"
}

get_domain() {
    show_progress "$((++CURRENT_STEP))" "Configuring domain"
    
    while [[ $domain != *[.]* ]]; do
        draw_content_box "Domain Setup"
        echo -e "${YELLOW}Please enter your domain (e.g., domain.com):${NC}"
        echo -ne "→ "
        read domain
    done
    echo -e "${GREEN}✓${NC} Domain set to: ${BLUE}${domain}${NC}"
}

generate_passwords() {
    show_progress "$((++CURRENT_STEP))" "Generating secure passwords"
    
    mariadbpwd=$(tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 20 | head -n 1)
    cronkey=$(tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 20 | head -n 1)
    echo -e "${GREEN}✓${NC} Passwords generated"
}

install_packages() {
    show_progress "$((++CURRENT_STEP))" "Installing packages"
    
    local packages=(
        "apache2"
        "mariadb-server"
        "php"
        "libapache2-mod-php"
        "php-intl"
        "php-mysqli"
        "php-curl"
        "php-imap"
        "php-mailparse"
        "libapache2-mod-md"
    )
    
    local total=${#packages[@]}
    local current=0
    
    for package in "${packages[@]}"; do
        ((current++))
        show_progress_bar $current $total
        
        if [ "$TEST_MODE" = true ]; then
            sleep 0.5
        else
            if ! apt-get install -y $package >/dev/null 2>&1; then
                echo -e "${RED}Failed to install $package${NC}"
                return 1
            fi
        fi
    done
    
    echo -e "${GREEN}✓${NC} Packages installed"
}

modify_php_ini() {
    show_progress "$((++CURRENT_STEP))" "Configuring PHP"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would modify PHP settings${NC}"
        return 0
    fi
    
    PHP_VERSION=$(php -v | head -n 1 | awk '{print $2}' | cut -d '.' -f 1,2)
    PHP_INI_PATH="/etc/php/${PHP_VERSION}/apache2/php.ini"
    
    local settings=(
        "upload_max_filesize = 5000M"
        "post_max_size = 5000M"
    )
    
    local total=${#settings[@]}
    local current=0
    
    for setting in "${settings[@]}"; do
        ((current++))
        show_progress_bar $current $total
        local key=$(echo $setting | cut -d= -f1)
        if ! sed -i "s/^;\?${key} =.*/${setting}/" $PHP_INI_PATH; then
            echo -e "${RED}Failed to modify ${key}${NC}"
            return 1
        fi
    done
    
    echo -e "${GREEN}✓${NC} PHP configured"
}

setup_webroot() {
    show_progress "$((++CURRENT_STEP))" "Setting up webroot"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would create: /var/www/${domain}${NC}"
        return 0
    fi
    
    if ! mkdir -p "/var/www/${domain}"; then
        echo -e "${RED}Failed to create web directory${NC}"
        return 1
    fi
    
    if ! chown -R www-data:www-data "/var/www/${domain}"; then
        echo -e "${RED}Failed to set permissions${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Webroot configured"
}

setup_apache() {
    show_progress "$((++CURRENT_STEP))" "Configuring Apache"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would configure Apache${NC}"
        return 0
    fi
    
    local steps=4
    local current=0
    
    ((current++))
    show_progress_bar $current $steps
    
    # Create virtual host
    cat > "/etc/apache2/sites-available/${domain}.conf" <<EOL
<VirtualHost *:80>
    ServerName ${domain}
    DocumentRoot /var/www/${domain}
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL
    
    ((current++))
    show_progress_bar $current $steps
    if ! a2ensite "${domain}.conf"; then
        echo -e "${RED}Failed to enable site${NC}"
        return 1
    fi
    
    ((current++))
    show_progress_bar $current $steps
    if ! a2dissite 000-default.conf; then
        echo -e "${RED}Failed to disable default site${NC}"
        return 1
    fi
    
    ((current++))
    show_progress_bar $current $steps
    if ! systemctl restart apache2; then
        echo -e "${RED}Failed to restart Apache${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Apache configured"
}

setup_mysql() {
    show_progress "$((++CURRENT_STEP))" "Setting up database"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would configure MySQL${NC}"
        return 0
    fi
    
    local steps=4
    local current=0
    
    ((current++))
    show_progress_bar $current $steps
    if ! mysql -e "CREATE DATABASE nestogy CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; then
        echo -e "${RED}Failed to create database${NC}"
        return 1
    fi
    
    ((current++))
    show_progress_bar $current $steps
    if ! mysql -e "CREATE USER 'nestogy'@'localhost' IDENTIFIED BY '${mariadbpwd}';"; then
        echo -e "${RED}Failed to create user${NC}"
        return 1
    fi
    
    ((current++))
    show_progress_bar $current $steps
    if ! mysql -e "GRANT ALL PRIVILEGES ON nestogy.* TO 'nestogy'@'localhost';"; then
        echo -e "${RED}Failed to grant privileges${NC}"
        return 1
    fi
    
    ((current++))
    show_progress_bar $current $steps
    if ! mysql -e "FLUSH PRIVILEGES;"; then
        echo -e "${RED}Failed to flush privileges${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Database configured"
}

clone_nestogy() {
    show_progress "$((++CURRENT_STEP))" "Cloning ITFlow-NG"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would clone ITFlow-NG${NC}"
        return 0
    fi
    
    local steps=3
    local current=0
    
    # Clone repository
    ((current++))
    show_progress_bar $current $steps
    if ! git clone https://github.com/twetech/itflow-ng.git "/var/www/${domain}" >/dev/null 2>&1; then
        echo -e "${RED}Failed to clone repository${NC}"
        return 1
    fi
    
    # Set permissions
    ((current++))
    show_progress_bar $current $steps
    if ! chown -R www-data:www-data "/var/www/${domain}"; then
        echo -e "${RED}Failed to set permissions${NC}"
        return 1
    fi
    
    # Configure environment
    ((current++))
    show_progress_bar $current $steps
    if ! cp "/var/www/${domain}/.env.example" "/var/www/${domain}/.env"; then
        echo -e "${RED}Failed to create environment file${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Repository cloned successfully"
}

setup_cronjobs() {
    show_progress "$((++CURRENT_STEP))" "Setting up automated tasks"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would configure cron jobs${NC}"
        return 0
    fi
    
    local steps=2
    local current=0
    
    # Create cron job
    ((current++))
    show_progress_bar $current $steps
    local cron_line="*/5 * * * * curl -s https://${domain}/cron.php?key=${cronkey} >/dev/null 2>&1"
    if ! (crontab -l 2>/dev/null | grep -Fq "$cron_line" || echo "$cron_line" | crontab -); then
        echo -e "${RED}Failed to create cron job${NC}"
        return 1
    fi
    
    # Verify cron job
    ((current++))
    show_progress_bar $current $steps
    if ! crontab -l | grep -Fq "$cron_line"; then
        echo -e "${RED}Failed to verify cron job${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Cron jobs configured"
}

generate_cronkey_file() {
    show_progress "$((++CURRENT_STEP))" "Generating cron key"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would generate cron key file${NC}"
        return 0
    fi
    
    local steps=2
    local current=0
    
    # Create key file
    ((current++))
    show_progress_bar $current $steps
    if ! echo "<?php define('CRON_KEY', '${cronkey}');" > "/var/www/${domain}/includes/cronkey.php"; then
        echo -e "${RED}Failed to create cron key file${NC}"
        return 1
    fi
    
    # Set permissions
    ((current++))
    show_progress_bar $current $steps
    if ! chmod 640 "/var/www/${domain}/includes/cronkey.php"; then
        echo -e "${RED}Failed to set cron key file permissions${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Cron key generated"
}

print_final_instructions() {
    draw_content_box "Installation Complete! 🎉"
    
    echo -e "\n📋 Next Steps:"
    echo -e "\n1. Set up SSL Certificate:"
    echo -e "   Run this command to get your DNS challenge:"
    echo -e "   ${YELLOW}sudo certbot certonly --manual --preferred-challenges dns --agree-tos --domains *.${domain}${NC}"
    
    echo -e "\n2. Complete Setup:"
    echo -e "   Visit: ${GREEN}https://${domain}${NC}"
    
    draw_content_box "Credentials"
    echo -e "Database User:     ${GREEN}nestogy${NC}"
    echo -e "Database Name:     ${GREEN}nestogy${NC}"
    echo -e "Database Password: ${GREEN}${mariadbpwd}${NC}"
    
    echo -e "\n⚠️  Important: Save these credentials in a secure location!"
    echo -e "\nFor support, visit: https://github.com/twetech/itflow-ng/issues"
    
    read -n 1 -p "Press any key to exit..."
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test)
                TEST_MODE=true
                shift
                ;;
            --domain)
                domain="$2"
                shift 2
                ;;
            *)
                echo "Unknown parameter: $1"
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    parse_args "$@"
    
    if [ "$TEST_MODE" = true ]; then
        run_tests
        exit $?
    fi
    
    # Setup terminal
    setup_terminal
    trap restore_terminal EXIT
    
    # Welcome message
    draw_content_box "Welcome"
    echo "Welcome to ITFlow-NG Installation"
    echo "Version: ${VERSION}"
    echo -e "\nThis script will:"
    echo " • Install required system packages"
    echo " • Configure Apache and PHP"
    echo " • Set up MariaDB database"
    echo " • Configure SSL certificates"
    echo " • Set up automated tasks"
    echo -e "\nPress any key to begin..."
    read -n 1
    
    # Run installation steps
    check_version
    verify_script
    check_root
    check_os
    get_domain
    generate_passwords
    install_packages
    modify_php_ini
    setup_webroot
    setup_apache
    setup_mysql
    clone_nestogy
    setup_cronjobs
    generate_cronkey_file
    
    # Show final instructions
    print_final_instructions
    
    # Restore terminal
    restore_terminal
}

# Add trap for clean exit
trap 'restore_terminal' EXIT INT TERM

# Start installation
main "$@"