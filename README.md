# Nestogy Installation Script

This script automates the installation of ITFlow-NG (Nestogy) on Ubuntu 24.04 systems.

## Requirements

- Ubuntu 24.04
- Root privileges
- Domain name pointed to your server

## Quick Install

Download and run the installation script:
```bash
curl -sSL https://raw.githubusercontent.com/o-psi/nestogy_install/main/i.sh -o i.sh && sudo bash i.sh
```

## What Does It Do?

The installation script:
- Verifies script integrity
- Checks system compatibility
- Installs required system packages
- Configures Apache and PHP
- Sets up MariaDB database
- Configures SSL certificates
- Sets up automated tasks

## Post-Installation

After installation completes:
1. Set up SSL Certificate using the provided DNS challenge command
2. Visit your domain to complete the web-based setup
3. Save your database credentials securely

## Security

The script includes:
- SHA256 verification
- Version checking
- Root privilege verification
- System compatibility checks

## Support

For issues and support:
- Open an issue in this repository
- Visit [ITFlow-NG Issues](https://github.com/twetech/itflow-ng/issues)

## License

[MIT License](LICENSE) 