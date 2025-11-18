#!/bin/bash
set -e

# Install MySQL server
apt update -y
apt install -y mysql-server

# Create database, user and table
mysql -e "CREATE DATABASE IF NOT EXISTS exampledb;"
mysql -e "CREATE USER IF NOT EXISTS 'appuser'@'localhost' IDENTIFIED BY '<your-password>'; GRANT ALL PRIVILEGES ON exampledb.* TO 'appuser'@'localhost'; FLUSH PRIVILEGES;"
mysql -e "CREATE TABLE IF NOT EXISTS exampledb.transactions (id INT AUTO_INCREMENT PRIMARY KEY, amount DECIMAL(10,2), description TEXT);"

# Write systemd unit with DB env vars
cat > /etc/systemd/system/ab3-app.service <<'UNIT'
[Unit]
Description=AB3 Node App
After=network.target

[Service]
Type=simple
User=moazadmin
WorkingDirectory=/home/moazadmin/app-tier
Environment=DB_HOST=localhost
Environment=DB_PORT=3306
Environment=DB_USER=appuser
....your pass env...value 
Environment=DB_DATABASE=exampledb
ExecStart=/usr/bin/node index.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

# Reload and restart service
systemctl daemon-reload
systemctl restart ab3-app.service

# Show status and last logs
systemctl status ab3-app.service --no-pager || true
journalctl -u ab3-app.service -n 200 --no-pager || true

# Test endpoints
curl -sS http://localhost:4000/health || true
curl -sS http://localhost:4000/transaction || true
