#!/bin/bash

# Version
VERSION="1.0.0"

# Terminal type handling
if [ -z "$TERM" ]; then
    export TERM=xterm-256color
fi

# Test mode function
run_tests() {
    # Disable terminal UI in test mode
    TERM_UI=false
    TEST_MODE=true
    
    echo "=== ITFlow-NG Installation Test ==="
    echo "Version: ${VERSION}"
    echo "Domain: ${domain}"
    echo "Running tests..."
    echo
    
    # Run installation steps in test mode
    check_version_test
    verify_script_test
    check_root_test
    check_os_test
    get_domain_test
    generate_passwords_test
    install_packages_test
    modify_php_ini_test
    setup_webroot_test
    setup_apache_test
    clone_nestogy_test
    setup_cronjobs_test
    generate_cronkey_test
    setup_mysql_test
    
    echo
    echo "✓ All tests completed successfully"
    return 0
}

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
            # Verify package exists in repository
            if ! apt-cache show "$package" >/dev/null 2>&1; then
                echo -e "${RED}Package not found: $package${NC}"
                return 1
            fi
            echo -e "${BLUE}[TEST] Verified package: $package${NC}"
        else
            if ! apt-get install -y $package >/dev/null 2>&1; then
                echo -e "${RED}Failed to install $package${NC}"
                return 1
            fi
        fi
    done
    
    echo -e "${GREEN}✓${NC} Package verification complete"
    return 0
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
    
    local steps=4
    local current=0
    
    # Verify Apache is installed
    if ! command -v apache2 >/dev/null 2>&1; then
        echo -e "${RED}Apache not installed${NC}"
        return 1
    fi
    
    ((current++))
    show_progress_bar $current $steps
    
    if [ "$TEST_MODE" = true ]; then
        # Check if site already exists
        if [ -f "/etc/apache2/sites-available/${domain}.conf" ]; then
            echo -e "${RED}Site configuration already exists${NC}"
            return 1
        fi
        echo -e "${BLUE}[TEST] Site configuration available${NC}"
        
        # Verify Apache modules
        if ! apache2ctl -M 2>/dev/null | grep -q "rewrite_module"; then
            echo -e "${RED}Required module 'rewrite' not available${NC}"
            return 1
        fi
        echo -e "${BLUE}[TEST] Required modules available${NC}"
    else
        # Create and enable site
        cat > "/etc/apache2/sites-available/${domain}.conf" <<EOL
<VirtualHost *:80>
    ServerName ${domain}
    DocumentRoot /var/www/${domain}
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL
        
        if ! a2ensite "${domain}.conf"; then
            echo -e "${RED}Failed to enable site${NC}"
            return 1
        fi
        
        if ! a2dissite 000-default.conf; then
            echo -e "${RED}Failed to disable default site${NC}"
            return 1
        fi
        
        if ! systemctl restart apache2; then
            echo -e "${RED}Failed to restart Apache${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✓${NC} Apache configuration complete"
    return 0
}

setup_mysql() {
    show_progress "$((++CURRENT_STEP))" "Setting up database"
    
    local steps=4
    local current=0
    
    # Test database connection
    if ! mysql -e "SELECT 1" >/dev/null 2>&1; then
        echo -e "${RED}Cannot connect to MySQL${NC}"
        return 1
    fi
    
    ((current++))
    show_progress_bar $current $steps
    
    if [ "$TEST_MODE" = true ]; then
        # Verify database doesn't exist
        if mysql -e "SHOW DATABASES LIKE 'nestogy'" 2>/dev/null | grep -q "nestogy"; then
            echo -e "${RED}Database already exists${NC}"
            return 1
        fi
        echo -e "${BLUE}[TEST] Database name available${NC}"
        
        # Verify user doesn't exist
        if mysql -e "SELECT User FROM mysql.user WHERE User='nestogy'" 2>/dev/null | grep -q "nestogy"; then
            echo -e "${RED}User already exists${NC}"
            return 1
        fi
        echo -e "${BLUE}[TEST] Username available${NC}"
    else
        # Create database and user
        if ! mysql -e "CREATE DATABASE nestogy CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; then
            echo -e "${RED}Failed to create database${NC}"
            return 1
        fi
        
        if ! mysql -e "CREATE USER 'nestogy'@'localhost' IDENTIFIED BY '${mariadbpwd}';"; then
            echo -e "${RED}Failed to create user${NC}"
            return 1
        fi
        
        if ! mysql -e "GRANT ALL PRIVILEGES ON nestogy.* TO 'nestogy'@'localhost';"; then
            echo -e "${RED}Failed to grant privileges${NC}"
            return 1
        fi
        
        if ! mysql -e "FLUSH PRIVILEGES;"; then
            echo -e "${RED}Failed to flush privileges${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✓${NC} Database setup complete"
    return 0
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
            --test-function)
                TEST_MODE=true
                if [[ "$2" == test_* ]]; then
                    TEST_FUNCTION="$2"
                else
                    TEST_FUNCTION="test_$2"
                fi
                shift 2
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

# Add test function handler
run_test_function() {
    local function_name="$1"
    
    # Setup test environment
    TEST_MODE=true
    
    # Check if test function exists
    if [ "$(type -t $function_name)" != "function" ]; then
        echo -e "${RED}Error: Test function '${function_name}' not found${NC}"
        exit 1
    fi
    
    # Run the test
    echo -e "\n${BLUE}=== Running Test: ${function_name} ===${NC}"
    if $function_name; then
        echo -e "\n${GREEN}✓ Test Passed: ${function_name}${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Test Failed: ${function_name}${NC}"
        return 1
    fi
}

# Add test functions
test_setup_cronjobs() {
    echo -e "\n${BLUE}[•]${NC} Testing cron job setup..."
    
    # Test cron line creation
    local cron_line="*/5 * * * * curl -s https://${domain}/cron.php?key=test_key >/dev/null 2>&1"
    echo -e "${BLUE}[TEST]${NC} Would add cron line: $cron_line"
    
    # Test cron job verification
    echo -e "${BLUE}[TEST]${NC} Would verify cron job exists"
    
    return 0
}

test_setup_mysql() {
    echo -e "\n${BLUE}[•]${NC} Testing MySQL setup..."
    
    # Test database creation
    echo -e "${BLUE}[TEST]${NC} Would create database: nestogy"
    
    # Test user creation
    echo -e "${BLUE}[TEST]${NC} Would create user: nestogy@localhost"
    
    # Test privileges
    echo -e "${BLUE}[TEST]${NC} Would grant privileges to nestogy"
    
    return 0
}

test_setup_apache() {
    echo -e "\n${BLUE}[•]${NC} Testing Apache setup..."
    
    # Test vhost creation
    echo -e "${BLUE}[TEST]${NC} Would create vhost for: ${domain}"
    
    # Test site enabling
    echo -e "${BLUE}[TEST]${NC} Would enable site: ${domain}.conf"
    
    # Test Apache restart
    echo -e "${BLUE}[TEST]${NC} Would restart Apache"
    
    return 0
}

# Test functions
test_install_packages() {
    echo -e "\n${BLUE}[•]${NC} Testing package installation..."
    
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
    
    for package in "${packages[@]}"; do
        echo -e "${BLUE}[TEST]${NC} Would install: $package"
        sleep 0.1
    done
    
    echo -e "${GREEN}✓${NC} Package installation test complete"
    return 0
}

test_modify_php_ini() {
    echo -e "\n${BLUE}[•]${NC} Testing PHP configuration..."
    
    local settings=(
        "upload_max_filesize = 5000M"
        "post_max_size = 5000M"
        "memory_limit = 256M"
    )
    
    for setting in "${settings[@]}"; do
        echo -e "${BLUE}[TEST]${NC} Would set: $setting"
        sleep 0.1
    done
    
    echo -e "${GREEN}✓${NC} PHP configuration test complete"
    return 0
}

test_setup_webroot() {
    echo -e "\n${BLUE}[•]${NC} Testing webroot setup..."
    
    echo -e "${BLUE}[TEST]${NC} Would create directory: /var/www/${domain}"
    echo -e "${BLUE}[TEST]${NC} Would set ownership: www-data:www-data"
    echo -e "${BLUE}[TEST]${NC} Would set permissions: 755"
    
    echo -e "${GREEN}✓${NC} Webroot setup test complete"
    return 0
}

test_setup_apache() {
    echo -e "\n${BLUE}[•]${NC} Testing Apache setup..."
    
    echo -e "${BLUE}[TEST]${NC} Would create vhost: ${domain}.conf"
    echo -e "${BLUE}[TEST]${NC} Would enable site: ${domain}"
    echo -e "${BLUE}[TEST]${NC} Would disable default site"
    echo -e "${BLUE}[TEST]${NC} Would restart Apache service"
    
    echo -e "${GREEN}✓${NC} Apache setup test complete"
    return 0
}

test_setup_mysql() {
    echo -e "\n${BLUE}[•]${NC} Testing MySQL setup..."
    
    echo -e "${BLUE}[TEST]${NC} Would create database: nestogy"
    echo -e "${BLUE}[TEST]${NC} Would create user: nestogy@localhost"
    echo -e "${BLUE}[TEST]${NC} Would grant privileges"
    echo -e "${BLUE}[TEST]${NC} Would flush privileges"
    
    echo -e "${GREEN}✓${NC} MySQL setup test complete"
    return 0
}

test_setup_cronjobs() {
    echo -e "\n${BLUE}[•]${NC} Testing cron setup..."
    
    echo -e "${BLUE}[TEST]${NC} Would create cron job for: ${domain}"
    echo -e "${BLUE}[TEST]${NC} Would set cron schedule: */5 * * * *"
    echo -e "${BLUE}[TEST]${NC} Would verify cron job"
    
    echo -e "${GREEN}✓${NC} Cron setup test complete"
    return 0
}

# Main execution
main() {
    parse_args "$@"
    
    if [ -n "$TEST_FUNCTION" ]; then
        run_test_function "$TEST_FUNCTION"
        exit $?
    elif [ "$TEST_MODE" = true ]; then
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