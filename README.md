# VPS WordPress Auto-Installation and Deletion Scripts

This repository contains scripts for automating the installation and deletion of WordPress sites on a VPS, including setup of Nginx, MariaDB, PHP-FPM, SSL certificates, and WordPress configurations.

## Prerequisites

- Ubuntu/Debian-based VPS
- Root or sudo access
- Internet connection for downloading packages and WordPress

The scripts will install the following if not present:
- Nginx
- MariaDB
- PHP 8.x with required extensions
- Certbot for SSL
- WP-CLI

## Configuration Files

### domains.txt
Located at `/home/ubuntu/domains.txt`. Contains one domain per line for which sites will be installed or deleted.

Example:
```
example.com
www.example.com
another.com
```

### Plugin and Theme Directories
- `/home/ubuntu/wp-auto-req/plugin/` - Place .zip files of plugins to install and activate.
- `/home/ubuntu/wp-auto-req/theme/` - Place .zip files of themes to install and activate (one theme per site).

### Favicon
- `/home/ubuntu/favicon.ico` - Favicon file to set for each site.

### Report File
- `/home/ubuntu/install-report.txt` - Logs installation details including database credentials.

## Scripts

### wp-auto-install.sh

Installs WordPress sites for each domain in `domains.txt`.

#### Features:
- Installs and configures Nginx, MariaDB, PHP-FPM, SSL.
- Downloads and installs WordPress core.
- Creates unique databases and users for each site.
- Installs plugins from `/home/ubuntu/wp-auto-req/plugin/`.
- Installs and activates one theme from `/home/ubuntu/wp-auto-req/theme/`.
- Deletes default WordPress plugins (Akismet, Hello Dolly) and themes (Twenty Twenty-Four, etc.).
- Deletes all default posts and pages.
- Sets up SSL certificates with Let's Encrypt.
- Configures permalinks, timezone, and favicon.
- Creates admin and publisher users with application passwords.

#### Usage:
```bash
sudo bash wp-auto-install.sh
```

#### Parallel Processing:
Installs up to 3 sites in parallel for faster processing.

#### Output:
- Sites are installed in `/var/www/<domain>/`
- Nginx configs in `/etc/nginx/sites-available/<domain>`
- SSL certificates managed by Certbot
- Report saved to `/home/ubuntu/install-report.txt`

### wp-auto-delete.sh

Deletes WordPress sites and all associated data for domains in `domains.txt`.

#### Features:
- Drops databases and database users.
- Removes Nginx configurations and reloads Nginx.
- Deletes SSL certificates.
- Removes site files from `/var/www/<domain>/`.
- Updates the install report by removing entries.

#### Usage:
```bash
sudo bash wp-auto-delete.sh
```

#### Complete Removal:
To completely remove MariaDB and MySQL from the server:
```bash
sudo systemctl stop mariadb; sudo apt-get purge -y mariadb-server mysql-server; sudo rm -rf /var/lib/mysql /etc/mysql /var/log/mysql /root/.mysql_root_pass; sudo apt-get autoremove -y; sudo apt-get autoclean
```

#### Note:
Ensure `domains.txt` contains the domains to delete. The script reads database info from the report file to clean up properly.

## Security Notes

- Database root password is generated and stored in `/root/.mysql_root_pass`.
- Each site has unique database credentials.
- Admin and publisher users are created with strong passwords.
- Application passwords are generated for API access.

## Troubleshooting

- Check logs in the terminal output.
- Ensure all prerequisites are met.
- Verify file permissions and paths.
- For SSL issues, check Certbot logs.

## Customization

Edit the script variables at the top for:
- Admin credentials
- Publisher credentials
- Application password name
- Titles and taglines arrays
- Parallel job count
- File paths

## License

This project is provided as-is for educational and automation purposes.