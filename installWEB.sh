#!/bin/bash

# Function to check if Nginx is installed
check_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo "Nginx is not installed."
        read -p "Do you want to install Nginx? (y/n): " install_nginx
        if [[ "$install_nginx" == "y" || "$install_nginx" == "Y" ]]; then
            sudo apt update
            sudo apt install nginx -y
            echo "Nginx installed successfully."
        else
            echo "Nginx is required to continue. Exiting."
            exit 1
        fi
    else
        echo "Nginx is already installed."
    fi
}

# Prompt user for domain name
read -p "Enter the domain name (e.g., example.com): " domain_name

# Prompt user for root directory
default_root="/var/www/$domain_name"
read -p "Enter the root directory for the site (default: $default_root): " root_dir
root_dir=${root_dir:-$default_root}

# Create directories and set permissions
echo "Creating directories..."
sudo mkdir -p "$root_dir"
sudo chown -R $USER:$USER "$root_dir"
sudo chmod -R 755 "$root_dir"
echo "<h1>Welcome to $domain_name</h1>" | sudo tee "$root_dir/index.html"

# Create Nginx configuration
nginx_conf="/etc/nginx/sites-available/$domain_name"
sudo bash -c "cat > $nginx_conf" <<EOL
server {
    listen 80;
    server_name $domain_name www.$domain_name;

    root $root_dir;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOL

# Enable the site
sudo ln -s "$nginx_conf" /etc/nginx/sites-enabled/

# Test Nginx configuration
echo "Testing Nginx configuration..."
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed. Exiting."
    exit 1
fi

# Reload Nginx
sudo systemctl reload nginx
echo "Nginx configuration for $domain_name has been created and enabled."

# Install Certbot if not installed
if ! command -v certbot &> /dev/null; then
    echo "Certbot is not installed. Installing..."
    sudo apt install certbot python3-certbot-nginx -y
fi

# Issue SSL certificate
echo "Issuing SSL certificate for $domain_name..."
sudo certbot --nginx -d "$domain_name" -d "www.$domain_name"

# Automate SSL renewal
echo "Automating SSL certificate renewal..."
if ! sudo crontab -l | grep -q "certbot renew"; then
    sudo crontab -l > mycron
    echo "0 3 * * * certbot renew --quiet" >> mycron
    sudo crontab mycron
    rm mycron
    echo "SSL certificate renewal has been automated."
else
    echo "SSL certificate renewal is already automated."
fi

# Final confirmation
echo "Site setup complete!"
echo "Domain: $domain_name"
echo "Root directory: $root_dir"
