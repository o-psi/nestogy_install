#!/bin/bash

# Version
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress indicator
show_progress() {
    echo -e "\n${BLUE}[$1/9]${NC} ${GREEN}$2...${NC}"
}
 
# Version check with styled output
check_version() {
    echo -e "\n${BLUE}[•]${NC} Checking for latest version..."
    LATEST_VERSION=$(curl -sSL https://raw.githubusercontent.com/o-psi/nestogy_install/refs/heads/main/version.txt)
    if [[ "$LATEST_VERSION" == "404: Not Found" ]]; then
        echo -e "${GREEN}✓${NC} Version check skipped - using local version: $VERSION"
        return 0
    elif [ "$VERSION" != "$LATEST_VERSION" ]; then
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║ A newer version ($LATEST_VERSION) is available! ║${NC}"
        echo -e "${RED}║ Please run the latest installer.                ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Running latest version"
} 

# Script verification with styled output
verify_script() {
    echo -e "\n${BLUE}[•]${NC} Verifying script integrity..."
    SCRIPT_HASH=$(curl -sSL https://raw.githubusercontent.com/o-psi/nestogy_install/refs/heads/main/i.sh.sha256)
    if ! echo "$SCRIPT_HASH $(basename $0)" | sha256sum -c - >/dev/null 2>&1; then
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║        Verification Failed!            ║${NC}"
        echo -e "${RED}║ Script may have been tampered with.    ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Script verified"
}

# Root check with styled output
check_root() {
    echo -e "\n${BLUE}[•]${NC} Checking permissions..."
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║    Error: Root privileges required     ║${NC}"
        echo -e "${RED}║    Please run with sudo or as root     ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Root privileges confirmed"
}

# OS check with styled output
check_os() {
    echo -e "\n${BLUE}[•]${NC} Checking system compatibility..."
    if ! grep -E "24.04" "/etc/"*"release" &>/dev/null; then
        echo -e "${RED}╔════════════════════════════════════════╗${NC}"
        echo -e "${RED}║    Error: Unsupported OS detected      ║${NC}"
        echo -e "${RED}║    Ubuntu 24.04 is required            ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════╝${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} System compatible"
}

# Get domain with styled input
get_domain() {
    echo -e "\n${BLUE}[•]${NC} Domain Configuration"
    while [[ $domain != *[.]* ]]; do
        echo -e "${YELLOW}Please enter your domain (e.g., domain.com):${NC}"
        echo -ne "→ "
        read domain
    done
    echo -e "${GREEN}✓${NC} Domain set to: ${BLUE}${domain}${NC}"
}

# Modified installation steps with progress indicators
install_packages() {
    show_progress "1" "Installing system packages"
    
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would run:${NC}"
        echo "apt-get update"
        echo "apt-get -y upgrade"
        echo "apt-get install -y apache2 mariadb-server php libapache2-mod-php..."
        return 0
    fi
    
    echo -e "${BLUE}[•]${NC} Updating package lists..."
    if ! apt-get update; then
        echo -e "${RED}Failed to update package lists${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[•]${NC} Upgrading existing packages..."
    if ! apt-get -y upgrade; then
        echo -e "${RED}Failed to upgrade packages${NC}"
        return 1
    fi
    
    echo -e "${BLUE}[•]${NC} Installing required packages..."
    if ! apt-get install -y apache2 mariadb-server php libapache2-mod-php php-intl \
    php-mysqli php-curl php-imap php-mailparse libapache2-mod-md \
    certbot python3-certbot-apache git sudo; then
        echo -e "${RED}Failed to install required packages${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Packages installed successfully"
}

generate_passwords() {
    mariadbpwd=$(tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 20 | head -n 1)
    cronkey=$(tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 20 | head -n 1)
}

modify_php_ini() {
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would modify:${NC}"
        echo "PHP Version: $(php -v | head -n 1)"
        echo "PHP INI Path: $PHP_INI_PATH"
        echo "Would set:"
        echo " - upload_max_filesize = 5000M"
        echo " - post_max_size = 5000M"
        return 0
    fi
    
    # Original function code
    PHP_VERSION=$(php -v | head -n 1 | awk '{print $2}' | cut -d '.' -f 1,2)
    PHP_INI_PATH="/etc/php/${PHP_VERSION}/apache2/php.ini"
    
    if ! sed -i 's/^;\?upload_max_filesize =.*/upload_max_filesize = 5000M/' $PHP_INI_PATH; then
        echo -e "${RED}Failed to modify upload_max_filesize${NC}"
        return 1
    fi
    
    if ! sed -i 's/^;\?post_max_size =.*/post_max_size = 5000M/' $PHP_INI_PATH; then
        echo -e "${RED}Failed to modify post_max_size${NC}"
        return 1
    fi
    
    return 0
}

setup_webroot() {
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would create:${NC}"
        echo "Directory: /var/www/${domain}"
        echo "Would set ownership: www-data:www-data"
        return 0
    fi
    
    if ! mkdir -p /var/www/${domain}; then
        echo -e "${RED}Failed to create webroot directory${NC}"
        return 1
    fi
    
    if ! chown -R www-data:www-data /var/www/; then
        echo -e "${RED}Failed to set webroot permissions${NC}"
        return 1
    fi
    
    return 0
}

setup_apache() {
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would configure Apache:${NC}"
        echo "Would create: /etc/apache2/sites-available/${domain}.conf"
        echo "Would enable site: ${domain}.conf"
        echo "Would disable: 000-default.conf"
        echo "Would restart Apache"
        return 0
    fi
    
    apache2_conf="<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName ${domain}
    DocumentRoot /var/www/${domain}
    ErrorLog /\${APACHE_LOG_DIR}/error.log
    CustomLog /\${APACHE_LOG_DIR}/access.log combined
</VirtualHost>"

    if ! echo "${apache2_conf}" > /etc/apache2/sites-available/${domain}.conf; then
        echo -e "${RED}Failed to create Apache configuration${NC}"
        return 1
    fi

    if ! a2ensite ${domain}.conf; then
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
    
    return 0
}

clone_nestogy() {
    # Clone the repository
    git clone https://github.com/twetech/itflow-ng.git /var/www/nestogy
    
    # Navigate to the project directory
    cd /var/www/${domain}
    
    # Install Composer if not already installed
    if ! [ -x "$(command -v composer)" ]; then
        echo -e "${BLUE}[•]${NC} Installing Composer..."
        curl -sS https://getcomposer.org/installer | php
        mv composer.phar /usr/local/bin/composer
        chmod +x /usr/local/bin/composer
    fi
    
    # Install dependencies
    echo -e "${BLUE}[•]${NC} Installing PHP dependencies..."
    composer install --no-dev --optimize-autoloader
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/${domain}
    chmod -R 755 /var/www/${domain}
}

setup_cronjobs() {
    (crontab -l 2>/dev/null; echo "0 2 * * * sudo -u www-data php /var/www/${domain}/cron.php ${cronkey}") | crontab -
    (crontab -l 2>/dev/null; echo "* * * * * sudo -u www-data php /var/www/${domain}/cron_ticket_email_parser.php ${cronkey}") | crontab -
    (crontab -l 2>/dev/null; echo "* * * * * sudo -u www-data php /var/www/${domain}/cron_mail_queue.php ${cronkey}") | crontab -
}

generate_cronkey_file() {
    mkdir -p /var/www/${domain}/uploads/tmp
    echo "<?php" > /var/www/${domain}/uploads/tmp/cronkey.php
    echo "\$nestogy_install_script_generated_cronkey = \"${cronkey}\";" >> /var/www/${domain}/uploads/tmp/cronkey.php
    echo "?>" >> /var/www/${domain}/uploads/tmp/cronkey.php
    chown -R www-data:www-data /var/www/
}

setup_mysql() {
    if [ "$TEST_MODE" = true ]; then
        echo -e "${BLUE}[TEST] Would configure MySQL:${NC}"
        echo "Would create database: nestogy"
        echo "Would create user: nestogy@localhost"
        echo "Would grant privileges on nestogy.* to nestogy@localhost"
        return 0
    fi
    
    if ! mysql -e "CREATE DATABASE nestogy /*\!40100 DEFAULT CHARACTER SET utf8 */;"; then
        echo -e "${RED}Failed to create database${NC}"
        return 1
    fi
    
    if ! mysql -e "CREATE USER nestogy@localhost IDENTIFIED BY '${mariadbpwd}';"; then
        echo -e "${RED}Failed to create MySQL user${NC}"
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
    
    return 0
}

# Welcome message with styled output
show_welcome_message() {
    clear
    echo -e "╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                                                               ║"
    echo -e "║                   ITFlow-NG Installation                      ║"
    echo -e "║                                                               ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "\n                     Version: ${VERSION}\n"
    echo -e "This script will:"
    echo -e " • Install required system packages"
    echo -e " • Configure Apache and PHP"
    echo -e " • Set up MariaDB database"
    echo -e " • Configure SSL certificates"
    echo -e " • Set up automated tasks"
    
    echo -e "\n${YELLOW}Requirements:${NC}"
    echo -e " ${BLUE}•${NC} Ubuntu 24.04"
    echo -e " ${BLUE}•${NC} Root privileges"
    echo -e " ${BLUE}•${NC} Domain name pointed to this server"
    
    echo -e "\n${YELLOW}Press ENTER to begin installation, or CTRL+C to exit...${NC}"
    read
    clear
}

# Final instructions with styled output
print_final_instructions() {
    clear
    echo -e "╔════════════════════════════════════════════════════════════════╗"
    echo -e "║                 Installation Complete! 🎉                       ║"
    echo -e "╚════════════════════════════════════════════════════════════════╝"
    echo -e "\n📋 Next Steps:"
    echo -e "\n1. Set up SSL Certificate:"
    echo -e "   Run this command to get your DNS challenge:"
    echo -e "   ${YELLOW}sudo certbot certonly --manual --preferred-challenges dns --agree-tos --domains *.${domain}${NC}"
    echo -e "\n2. Complete Setup:"
    echo -e "   Visit: ${GREEN}https://${domain}${NC}"
    echo -e "\n3. Database Credentials:"
    echo -e "   ┌─────────────────────────────────────────────┐"
    echo -e "   │ Database User:     ${GREEN}nestogy${NC}"
    echo -e "   │ Database Name:     ${GREEN}nestogy${NC}"
    echo -e "   │ Database Password: ${GREEN}${mariadbpwd}${NC}"
    echo -e "   └─────────────────────────────────────────────┘"
    echo -e "\n⚠️  Important: Save these credentials in a secure location!"
    echo -e "\nFor support, visit: https://github.com/twetech/itflow-ng/issues\n"
}

# Add test mode flag
TEST_MODE=false

# Define all test functions first
test_install_packages() {
    echo "Testing package installation prerequisites..."
    
    # Check if apt is available
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "✗ apt-get is not available"
        return 1
    fi
    
    # Check if we can update package lists
    if ! apt-get update >/dev/null 2>&1; then
        echo "✗ Cannot update package lists"
        return 1
    fi
    
    echo "✓ Package installation prerequisites met"
    return 0
}

test_modify_php_ini() {
    echo "Testing PHP INI modifications..."
    
    # Check if PHP is installed
    if ! command -v php >/dev/null 2>&1; then
        echo "✗ PHP is not installed"
        return 1
    fi
    
    echo "✓ PHP configuration prerequisites met"
    return 0
}

test_setup_webroot() {
    echo "Testing webroot setup..."
    
    # Check if /var/www exists
    if [ ! -d "/var/www" ]; then
        echo "✗ /var/www directory does not exist"
        return 1
    fi
    
    echo "✓ Webroot prerequisites met"
    return 0
}

test_setup_apache() {
    echo "Testing Apache setup..."
    
    # Check if Apache is installed
    if ! command -v apache2 >/dev/null 2>&1; then
        echo "✗ Apache2 is not installed"
        return 1
    fi
    
    echo "✓ Apache prerequisites met"
    return 0
}

test_setup_mysql() {
    echo "Testing MySQL/MariaDB setup..."
    
    # Check if MySQL/MariaDB is installed
    if ! command -v mysql >/dev/null 2>&1; then
        echo "✗ MySQL/MariaDB is not installed"
        return 1
    fi
    
    echo "✓ MySQL prerequisites met"
    return 0
}

test_setup_cronjobs() {
    echo "Testing cronjob setup..."
    
    # Check if crontab is available
    if ! command -v crontab >/dev/null 2>&1; then
        echo "✗ Crontab is not available"
        return 1
    fi
    
    echo "✓ Crontab prerequisites met"
    return 0
}

# Then define run_tests
run_tests() {
    if [ -n "$TEST_FUNCTION" ]; then
        echo -e "${BLUE}Running test for: $TEST_FUNCTION${NC}"
        $TEST_FUNCTION
        return $?
    fi

    # Run all tests
    local tests=(
        "test_install_packages"
        "test_modify_php_ini"
        "test_setup_webroot"
        "test_setup_apache"
        "test_setup_mysql"
        "test_setup_cronjobs"
    )
    
    local failed=0
    for test in "${tests[@]}"; do
        echo -e "\n${BLUE}Running $test...${NC}"
        if ! $test; then
            echo -e "${RED}✗ $test failed${NC}"
            failed=$((failed + 1))
        else
            echo -e "${GREEN}✓ $test passed${NC}"
        fi
    done
    
    if [ $failed -gt 0 ]; then
        echo -e "\n${RED}$failed test(s) failed${NC}"
        return 1
    else
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    fi
}

# Then define parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --test)
                TEST_MODE=true
                shift
                ;;
            --test-function)
                TEST_MODE=true
                TEST_FUNCTION="$2"
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

# Finally, the main function
main() {
    parse_args "$@"

    if [ "$TEST_MODE" = true ]; then
        run_tests
        exit $?
    fi

    # Regular execution flow
    show_welcome_message
    check_version
    verify_script
    check_root
    check_os
    get_domain
    generate_passwords

    # Execute installation steps with progress tracking
    install_packages
    modify_php_ini
    setup_webroot
    setup_apache
    clone_nestogy
    setup_cronjobs
    generate_cronkey_file
    setup_mysql

    # Show final instructions
    print_final_instructions
}

# Call main with all arguments
main "$@"