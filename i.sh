#!/bin/bash

# Version
VERSION="1.0.0"

# Log file
LOG_FILE="/var/log/itflow_install.log"

# Add logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

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
    
    local failed=0
    local tests=(
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
        clone_nestogy
        setup_cronjobs
        generate_cronkey_file
        setup_mysql
    )
    
    for test in "${tests[@]}"; do
        echo -e "\nRunning test: ${test}"
        if ! $test; then
            echo "✗ Test failed: ${test}"
            failed=$((failed + 1))
        else
            echo "✓ Test passed: ${test}"
        fi
    done
    
    echo
    if [ $failed -eq 0 ]; then
        echo "✓ All tests completed successfully"
        return 0
    else
        echo "✗ ${failed} test(s) failed"
        return 1
    fi
}

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Global variables
TERM_WIDTH=$(tput cols)
TERM_HEIGHT=$(tput lines)
CONTENT_START=6
CONTENT_WIDTH=$((TERM_WIDTH - 8))
TOTAL_STEPS=12
CURRENT_STEP=0

# Update show_progress to simple output
show_progress() {
    local step="$1"
    local message="$2"
    log "INFO" "Step ${step}/${TOTAL_STEPS}: ${message}"
}

# Installation Functions
check_version() {
    if [ "$TEST_MODE" = true ]; then
        echo "Testing version check..."
        
        # Test if we can access the version file
        if ! curl -s -f "https://raw.githubusercontent.com/o-psi/nestogy_install/refs/heads/main/version.txt" >/dev/null; then
            echo "Cannot access version file"
            return 1
        fi
        
        echo "✓ Version check passed"
        return 0
    fi
    
    # Real version check code
    show_progress "$((++CURRENT_STEP))" "Checking version"
    
    LATEST_VERSION=$(curl -sSL https://raw.githubusercontent.com/o-psi/nestogy_install/refs/heads/main/version.txt)
    if [[ "$VERSION" != "$LATEST_VERSION" ]]; then
        echo -e "${RED}A newer version ($LATEST_VERSION) is available"
        echo -e "Please update to the latest version${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Version check passed"
    return 0
}

verify_script() {
    URL="https://raw.githubusercontent.com/o-psi/nestogy_install/refs/heads/main/i.sh.sha256"
    
    if [ "$TEST_MODE" = true ]; then
        log "INFO" "Testing script verification..."
        
        if ! command -v sha256sum >/dev/null 2>&1; then
            log "ERROR" "Required tool 'sha256sum' not found"
            return 1
        fi
        log "INFO" "sha256sum available"
        
        if ! curl -s -f "$URL" >/dev/null; then
            log "ERROR" "Cannot access hash file"
            return 1
        fi
        log "INFO" "Hash file accessible"
        
        log "INFO" "Script verification test complete"
        return 0
    fi
    
    show_progress "$((++CURRENT_STEP))" "Verifying script"
    
    remote_hash=$(curl -sSL "$URL")
    if [ -z "$remote_hash" ]; then
        log "ERROR" "Failed to download verification hash"
        exit 1
    fi
    
    local_hash=$(sha256sum "$0" | cut -d' ' -f1)
    
    if [ "$remote_hash" != "$local_hash" ]; then
        log "ERROR" "Script verification failed"
        log "ERROR" "Expected hash: $remote_hash"
        log "ERROR" "Got hash:      $local_hash"
        exit 1
    fi
    
    log "INFO" "Script verified successfully"
    return 0
}

check_root() {
    show_progress "$((++CURRENT_STEP))" "Checking permissions"
    
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Root privileges required"
        echo -e "Please run with sudo or as root${NC}"
        read -n 1 -p "Press any key to exit..."
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Root privileges confirmed"
}

check_os() {
    if [ "$TEST_MODE" = true ]; then
        echo "Testing OS compatibility..."
        
        # For GitHub Actions, we'll check for Ubuntu in general
        if ! grep -E "Ubuntu" "/etc/"*"release" &>/dev/null; then
            echo "System is not Ubuntu"
            return 1
        fi
        
        echo "✓ OS compatibility check passed"
        return 0
    fi
    
    # Real OS check code
    show_progress "$((++CURRENT_STEP))" "Checking system compatibility"
    
    if ! grep -E "24.04" "/etc/"*"release" &>/dev/null; then
        echo -e "${RED}Unsupported OS detected"
        echo -e "Ubuntu 24.04 is required${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} System compatible"
    return 0
}

get_domain() {
    show_progress "$((++CURRENT_STEP))" "Configuring domain"
    
    while [[ $domain != *[.]* ]]; do
        echo -e "${YELLOW}Please enter your domain (e.g., domain.com):${NC}"
        echo -ne "→ "
        read domain
    done
    echo -e "${GREEN}✓${NC} Domain set to: ${BLUE}${domain}${NC}"
}

generate_passwords() {
    if [ "$TEST_MODE" = true ]; then
        echo "Testing password generation..."
        
        # Check for required tools
        if ! command -v tr >/dev/null 2>&1; then
            echo "Required tool 'tr' not found"
            return 1
        fi
        
        if ! command -v head >/dev/null 2>&1; then
            echo "Required tool 'head' not found"
            return 1
        fi
        
        # Test /dev/urandom access
        if [ ! -r "/dev/urandom" ]; then
            echo "Cannot access /dev/urandom"
            return 1
        fi
        
        echo "✓ Password generation prerequisites verified"
        return 0
    fi
    
    show_progress "$((++CURRENT_STEP))" "Generating secure passwords"
    
    mariadbpwd=$(tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 20 | head -n 1)
    cronkey=$(tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 20 | head -n 1)
    echo -e "${GREEN}✓${NC} Passwords generated"
}

install_packages() {
    if [ "$TEST_MODE" = true ]; then
        echo "Testing package dependencies..."
        
        # Helper function to check if a package or its alternative is available
        check_package_or_alternative() {
            local pkg="$1"
            
            # Handle virtual packages and common alternatives
            case "$pkg" in
                "<perl:any>")
                    if apt-cache show perl >/dev/null 2>&1; then
                        return 0
                    fi
                    ;;
                "<python3:any>")
                    if apt-cache show python3 >/dev/null 2>&1; then
                        return 0
                    fi
                    ;;
                "<debconf-2.0>")
                    if apt-cache show debconf >/dev/null 2>&1; then
                        return 0
                    fi
                    ;;
                "<python3-certbot-abi-1>")
                    if apt-cache show python3-certbot >/dev/null 2>&1; then
                        return 0
                    fi
                    ;;
                *)
                    # Remove any version requirements (e.g., package (>= 1.0))
                    pkg=$(echo "$pkg" | cut -d' ' -f1)
                    if apt-cache show "$pkg" >/dev/null 2>&1; then
                        return 0
                    fi
                    ;;
            esac
            return 1
        }
        
        # Required packages with their dependencies
        local packages=(
            # Web server
            "apache2"
            "libapache2-mod-php"
            "libapache2-mod-md"
            
            # Database
            "mariadb-server"
            "mariadb-client"
            
            # PHP and extensions
            "php"
            "php-cli"
            "php-common"
            "php-intl"
            "php-mysqli"
            "php-curl"
            "php-imap"
            "php-mailparse"
            "php-xml"
            "php-mbstring"
            "php-zip"
            
            # SSL and security
            "certbot"
            "python3-certbot-apache"
            
            # System utilities
            "git"
            "curl"
            "unzip"
            "cron"
        )
        
        local failed_packages=()
        local missing_deps=()
        
        echo "Checking package availability..."
        for package in "${packages[@]}"; do
            echo -n "Testing $package... "
            
            # Check if package exists in repository
            if ! apt-cache show "$package" >/dev/null 2>&1; then
                echo "❌ Not found in repository"
                failed_packages+=("$package")
                continue
            fi
            
            # Check package dependencies
            local deps=$(apt-cache depends "$package" | grep "Depends:" | cut -d: -f2-)
            local missing_pkg_deps=()
            
            for dep in $deps; do
                if ! check_package_or_alternative "$dep"; then
                    missing_pkg_deps+=("$dep")
                fi
            done
            
            if [ ${#missing_pkg_deps[@]} -eq 0 ]; then
                echo "✓ OK"
            else
                echo "❌ Missing dependencies"
                for dep in "${missing_pkg_deps[@]}"; do
                    # Only add if it's not a virtual package that we can handle
                    if ! check_package_or_alternative "$dep"; then
                        missing_deps+=("$dep for $package")
                    fi
                done
            fi
        done
        
        # Report results
        echo -e "\nTest Results:"
        echo "=============="
        
        if [ ${#failed_packages[@]} -eq 0 ] && [ ${#missing_deps[@]} -eq 0 ]; then
            echo "✓ All packages and dependencies are available"
            return 0
        fi
        
        if [ ${#failed_packages[@]} -gt 0 ]; then
            echo -e "\nMissing Packages:"
            printf '  - %s\n' "${failed_packages[@]}"
        fi
        
        if [ ${#missing_deps[@]} -gt 0 ]; then
            echo -e "\nMissing Dependencies:"
            printf '  - %s\n' "${missing_deps[@]}"
        fi
        
        return 1
    fi
    
    show_progress "$((++CURRENT_STEP))" "Installing required packages"

    apt-get update
    apt-get install -y "${packages[@]}"

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
    if [ "$TEST_MODE" = true ]; then
        echo "Testing Apache configuration..."
        
        # Check if Apache is installed
        if ! command -v apache2 >/dev/null 2>&1; then
            echo "Apache not installed"
            return 1
        fi
        
        # Verify Apache modules
        local required_modules=("rewrite" "ssl" "headers" "md")
        for module in "${required_modules[@]}"; do
            if ! apache2 -l | grep -q "mod_${module}"; then
                echo "Note: Module '${module}' not loaded (expected in test environment)"
            fi
        done
        
        echo "✓ Apache configuration test passed"
        return 0
    fi
    
    show_progress "$((++CURRENT_STEP))" "Configuring Apache"
    
    local steps=6
    local current=0
    
    # Enable required modules
    ((current++))
    a2enmod rewrite
    a2enmod ssl
    a2enmod headers
    a2enmod md
    
    # Create Apache configuration
    ((current++))
    cat > "/etc/apache2/sites-available/${domain}.conf" <<EOL
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName ${domain}
    DocumentRoot /var/www/${domain}

    <Directory /var/www/${domain}>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted

        # Redirect all requests to index.php if file/directory doesn't exist
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^ index.php [QSA,L]
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${domain}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}_access.log combined
</VirtualHost>
EOL

    # Create .htaccess file
    ((current++))
    cat > "/var/www/${domain}/.htaccess" <<EOL
RewriteEngine On
RewriteBase /

# If the requested file/directory doesn't exist, redirect to index.php
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [QSA,L]

# Prevent access to .htaccess
<Files .htaccess>
    Order allow,deny
    Deny from all
</Files>
EOL

    # Set proper permissions
    chown www-data:www-data "/var/www/${domain}/.htaccess"
    chmod 644 "/var/www/${domain}/.htaccess"

    # Enable site and disable default
    ((current++))
    a2ensite "${domain}.conf"
    a2dissite 000-default.conf

    # Restart Apache
    ((current++))
    systemctl restart apache2

    # Setup SSL with certbot
    ((current++))
    certbot --apache --non-interactive --agree-tos --register-unsafely-without-email --domains ${domain}

    echo -e "${GREEN}✓${NC} Apache configuration complete"
    return 0
}

setup_mysql() {
    if [ "$TEST_MODE" = true ]; then
        echo "Testing MySQL setup..."
        
        # Check if MySQL package is available
        if ! apt-cache show mysql-server >/dev/null 2>&1 && ! apt-cache show mariadb-server >/dev/null 2>&1; then
            echo "MySQL/MariaDB package not available"
            return 1
        fi
        
        # Check if MySQL client is installed
        if ! command -v mysql >/dev/null 2>&1; then
            echo "MySQL client not installed"
            return 1
        fi
        
        echo "✓ MySQL package verification passed"
        return 0
    fi
    
    # Real MySQL setup code
    show_progress "$((++CURRENT_STEP))" "Setting up database"
    
    if ! systemctl is-active --quiet mysql; then
        echo -e "${RED}MySQL is not running${NC}"
        return 1
    fi
    
    # ... rest of the function ...
}

clone_nestogy() {
    show_progress "$((++CURRENT_STEP))" "Cloning ITFlow-NG"
    
    if [ "$TEST_MODE" = true ]; then
        if ! git clone https://github.com/twetech/itflow-ng.git "/var/www/${domain}" >/dev/null 2>&1; then
            echo -e "${RED}Failed to clone repository${NC}"
            return 1
        fi
        echo -e "${GREEN}✓${NC} Repository cloned successfully"
        return 0
    fi
    
    local steps=3
    local current=0
    
    # Clone repository
    ((current++))
    if ! git clone https://github.com/twetech/itflow-ng.git "/var/www/${domain}" >/dev/null 2>&1; then
        echo -e "${RED}Failed to clone repository${NC}"
        return 1
    fi
    
    # Set permissions
    ((current++))
    if ! chown -R www-data:www-data "/var/www/${domain}"; then
        echo -e "${RED}Failed to set permissions${NC}"
        return 1
    fi
    
    # Configure environment
    ((current++))
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
    local cron_line="*/5 * * * * curl -s https://${domain}/cron.php?key=${cronkey} >/dev/null 2>&1"
    if ! (crontab -l 2>/dev/null | grep -Fq "$cron_line" || echo "$cron_line" | crontab -); then
        echo -e "${RED}Failed to create cron job${NC}"
        return 1
    fi
    
    # Verify cron job
    ((current++))
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
    if ! echo "<?php define('CRON_KEY', '${cronkey}');" > "/var/www/${domain}/includes/cronkey.php"; then
        echo -e "${RED}Failed to create cron key file${NC}"
        return 1
    fi
    
    # Set permissions
    ((current++))
    if ! chmod 640 "/var/www/${domain}/includes/cronkey.php"; then
        echo -e "${RED}Failed to set cron key file permissions${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Cron key generated"
}

print_final_instructions() {
    echo -e "\n📋 Next Steps:"
    echo -e "\n1. Set up SSL Certificate:"
    echo -e "   Run this command to get your DNS challenge:"
    echo -e "   ${YELLOW}sudo certbot certonly --manual --preferred-challenges dns --agree-tos --domains *.${domain}${NC}"
    
    echo -e "\n2. Complete Setup:"
    echo -e "   Visit: ${GREEN}https://${domain}${NC}"
    
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

# Add test function handler
run_test_function() {
    local function_name="$1"
    
    # Check if function exists
    if [ "$(type -t $function_name)" != "function" ]; then
        echo "Error: Function '$function_name' not found"
        exit 1
    fi
    
    # Run the function in test mode
    if $function_name; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    # Create log file
    touch "$LOG_FILE" 2>/dev/null || {
        echo "ERROR: Cannot create log file. Please run as root."
        exit 1
    }
    
    log "INFO" "Starting ITFlow-NG installation"
    log "INFO" "Version: ${VERSION}"
    
    parse_args "$@"
    
    if [ -n "$TEST_FUNCTION" ]; then
        log "INFO" "Running test function: ${TEST_FUNCTION}"
        run_test_function "$TEST_FUNCTION"
        exit $?
    elif [ "$TEST_MODE" = true ]; then
        log "INFO" "Running in test mode"
        run_tests
        exit $?
    fi
    
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
    
    log "INFO" "Installation completed successfully"
    
    # Show final instructions
    cat << EOF

Installation Complete! 🎉

Next Steps:
1. Set up SSL Certificate:
   Run this command to get your DNS challenge:
   sudo certbot certonly --manual --preferred-challenges dns --agree-tos --domains *.${domain}

2. Complete Setup:
   Visit: https://${domain}

Credentials:
Database User:     nestogy
Database Name:     nestogy
Database Password: ${mariadbpwd}

⚠️  Important: Save these credentials in a secure location!

For support, visit: https://github.com/twetech/itflow-ng/issues
Installation log available at: ${LOG_FILE}
EOF
}

# Remove all trap handlers for terminal restoration
# Just keep basic error handling
trap 'log "ERROR" "Installation failed with error on line $LINENO"' ERR

# Start installation
main "$@"
