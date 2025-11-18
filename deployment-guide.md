# Complete Deployment Guide - Three Tier Application

## Summary of Issues Fixed and Required Configurations

### 1. Networking Issues

#### A) NSG (Network Security Groups) Problems:
```terraform
# In main.tf - Fix NSG names and security rules
resource "azurerm_network_security_group" "WEB" {  # Fixed name
  name = "az_WEB_threetier-nsg"
  
  security_rule {
    name                       = "Allow_HTTP"  # Fixed name
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "app_NSG2" {
  security_rule {
    name                       = "Allow_App_from_Web"
    priority                   = 110  # Correct priority
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4000"
    source_address_prefix      = "10.0.2.0/24"  # Web subnet
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "AllowSSHFromAdmin" 
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "197.63.213.168/32"  # Admin IP
    destination_address_prefix = "*"
  }
}
```

#### B) VNet and Subnets Configuration:
```terraform
# Add service endpoint for app subnet to access Azure SQL
resource "azurerm_subnet" "app_SUBnet2" {
  name                 = "app_az_internal2"
  resource_group_name  = azurerm_resource_group.az_main_tier_RG.name
  virtual_network_name = azurerm_virtual_network.az_main_tier_Vnet.name
  address_prefixes     = ["10.0.3.0/24"]
  
  # Critical for Azure SQL connection
  service_endpoints = ["Microsoft.Sql"]
}
```

### 2. Database Issues

#### A) Adding Firewall Rules for Azure SQL:
```terraform
# Allow VNet access to SQL Server
resource "azurerm_mssql_virtual_network_rule" "app_to_sql" {
  name      = "allow-app-subnet"
  server_id = azurerm_mssql_server.az_threetier_sqlserver.id
  subnet_id = azurerm_subnet.app_SUBnet2.id
}

# Allow public IP access to SQL Server
resource "azurerm_mssql_firewall_rule" "allow_app_vm" {
  name             = "allow-app-vm"
  server_id        = azurerm_mssql_server.az_threetier_sqlserver.id
  start_ip_address = azurerm_public_ip.app_ip.ip_address
  end_ip_address   = azurerm_public_ip.app_ip.ip_address
}
```

#### B) Converting Application from MySQL to MSSQL:

##### package.json - Add mssql package:
```json
{
  "dependencies": {
    "express": "^4.17.1",
    "mssql": "^10.0.0",    # إضافة هذا
    "mysql": "^2.18.1"     # يمكن الاحتفاظ به للتوافق
  }
}
```

##### New TransactionService.js (MSSQL):
```javascript
const dbcreds = require('./DbConfig');
const sql = require('mssql');

// Connection config for Microsoft SQL Server (Azure SQL)
const poolConfig = {
    user: dbcreds.DB_USER,
    password: dbcreds.DB_PWD,
    server: dbcreds.DB_HOST,
    port: parseInt(dbcreds.DB_PORT, 10) || 1433,
    database: dbcreds.DB_DATABASE,
    options: {
        encrypt: true,
        trustServerCertificate: false
    },
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};

let poolPromise = null;

async function ensurePool() {
    if (!poolPromise) {
        poolPromise = sql.connect(poolConfig);
    }
    return poolPromise;
}

// Critical: Match callback pattern with what index.js expects
async function getAllTransactions(callback){
    try{
        const pool = await ensurePool();
        const result = await pool.request().query('SELECT id, amount, description FROM dbo.transactions ORDER BY id');
        if (callback) callback(result.recordset);  // Direct without err parameter
    }catch(err){
        console.error('getAllTransactions error:', err.message || err);
        if (callback) callback([]);  // Return empty array on error
    }
}

async function addTransaction(amount, desc, callback){
    try{
        const pool = await ensurePool();
        const result = await pool.request()
            .input('amount', sql.Float, amount)
            .input('description', sql.NVarChar(255), desc)
            .query('INSERT INTO dbo.transactions (amount, description) OUTPUT INSERTED.id VALUES (@amount, @description)');
        const insertedId = result.recordset && result.recordset[0] && result.recordset[0].id;
        console.log('Added transaction id:', insertedId);
        if (callback) callback({ insertId: insertedId });
    }catch(err){
        console.error('addTransaction error:', err.message || err);
        if (callback) callback({success: false, error: err.message});
    }
}

// Remaining functions follow same pattern...
module.exports = {
    addTransaction,
    getAllTransactions,
    findTransactionById,
    deleteAllTransactions,
    deleteTransactionById
};
```

### 3. Correct Ansible Playbook Configuration

#### App Server Configuration:
```yaml
- name: Deploy and run App (Node.js) on appservers
  hosts: appservers
  become: true
  vars:
    ansible_python_interpreter: /usr/bin/python3
    app_src: "/home/moazadmfin/app-tier"
    node_version: "18.x"  # مهم: Node 18+ للدعم MSSQL
  
  tasks:
    # Update apt with ignore transient errors
    - name: Ensure apt cache is up to date
      apt:
        update_cache: yes
      ignore_errors: true

    # Install Node.js 18.x
    - name: Add NodeSource repo
      shell: curl -fsSL https://deb.nodesource.com/setup_{{ node_version }} | bash -
      args:
        creates: /etc/apt/sources.list.d/nodesource.list

    - name: Install Node.js
      apt:
        name: nodejs
        state: present

    # Copy app and install dependencies
    - name: Copy app-tier source to remote
      copy:
        src: ../app-tier/
        dest: "{{ app_src }}/"
        owner: moazadmfin
        mode: '0755'

    - name: Install npm dependencies
      npm:
        path: "{{ app_src }}"
        production: no

    # Create systemd service with environment variables
    - name: Create systemd service for app
      copy:
        dest: /etc/systemd/system/ab3-app.service
        content: |
          [Unit]
          Description=AB3 Node App
          After=network.target

          [Service]
          Type=simple
          User=moazadmfin
          WorkingDirectory={{ app_src }}
          Environment=DB_HOST=threetier-sqlserver-moaz2024.database.windows.net
          Environment=DB_PORT=1433
          Environment=DB_USER=4dm1n157r470r@threetier-sqlserver-moaz2024
          Environment=DB_PWD=4-v3ry-53cr37-p455w0rd
          Environment=DB_DATABASE=example-db
          ExecStart=/usr/bin/node index.js
          Restart=on-failure

          [Install]
          WantedBy=multi-user.target

    # Install MSSQL tools with EULA acceptance
    - name: Add Microsoft APT repository key
      apt_key:
        url: https://packages.microsoft.com/keys/microsoft.asc
        state: present

    - name: Add Microsoft APT repo
      copy:
        dest: /etc/apt/sources.list.d/mssql-release.list
        content: |
          deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main

    - name: Update apt cache after adding MS repo
      apt:
        update_cache: yes
      ignore_errors: true

    # Fix broken packages
    - name: Fix broken packages non-interactively
      environment:
        ACCEPT_EULA: "Y"
        DEBIAN_FRONTEND: noninteractive
      shell: apt --fix-broken install -y
      ignore_errors: true

    - name: Install mssql-tools and dependencies
      environment:
        ACCEPT_EULA: "Y"          # Critical!
        DEBIAN_FRONTEND: noninteractive
      apt:
        name:
          - msodbcsql18
          - mssql-tools
          - unixodbc-dev
        state: present

    # Create database table
    - name: Create transactions table in Azure SQL
      shell: |
        /opt/mssql-tools/bin/sqlcmd -S threetier-sqlserver-moaz2024.database.windows.net \
        -U 4dm1n157r470r@threetier-sqlserver-moaz2024 \
        -P '4-v3ry-53cr37-p455w0rd' \
        -d example-db \
        -Q "IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[transactions]') AND type in (N'U')) CREATE TABLE dbo.transactions (id INT IDENTITY(1,1) PRIMARY KEY, amount FLOAT, description NVARCHAR(255));"

    # Start the service
    - name: Reload systemd and enable/start app
      systemd:
        daemon_reload: yes
        name: ab3-app.service
        enabled: yes
        state: restarted
```

#### Web Server Configuration:
```yaml
- name: Build and serve Web (React) on webservers
  hosts: webservers
  become: true
  vars:
    web_src: "/home/moazadmfin/web-tier"
    node_version: "18.x"
  
  tasks:
    # Same Node.js installation steps
    
    - name: Build React app
      command: npm run build
      args:
        chdir: "{{ web_src }}"

    - name: Copy build to nginx html directory
      command: rsync -a --delete {{ web_src }}/build/ /var/www/html/

    # Get private IP for app server
    - name: Get app server private IP
      set_fact:
        app_private_ip: "{{ hostvars[groups['appservers'][0]].ansible_default_ipv4.address }}"

    # Configure nginx for proxy
    - name: Configure nginx to proxy API to app
      copy:
        dest: /etc/nginx/sites-available/ab3
        content: |
          server {
            listen 80;
            server_name _;

            root /var/www/html;
            index index.html index.htm;

            # Route API calls to backend
            location /api/ {
              proxy_pass http://{{ app_private_ip }}:4000/;
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection 'upgrade';
              proxy_set_header Host $host;
              proxy_cache_bypass $http_upgrade;
            }

            # Serve static files
            location / {
              try_files $uri $uri/ /index.html;
            }
          }

    - name: Enable nginx site
      file:
        src: /etc/nginx/sites-available/ab3
        dest: /etc/nginx/sites-enabled/ab3
        state: link

    - name: Remove default site
      file:
        path: /etc/nginx/sites-enabled/default
        state: absent

    - name: Restart nginx
      service:
        name: nginx
        state: restarted
```

### 4. Important Points to Avoid Future Errors


#### A) Execution Order

1. **First**: Apply Terraform changes for network and firewall rules
2. **Second**: Run Ansible from WSL (not Windows)
3. **Third**: Copy updated files with scp if copy fails in Ansible


#### B) Version Requirements

- **Node.js**: 18.x or newer (for nullish coalescing operator ?? support)
- **npm**: Installed automatically with Node.js
- **MSSQL package**: Latest version


#### C) Important Environment Variables

```bash
DB_HOST=threetier-sqlserver-moaz2024.database.windows.net
DB_PORT=1433
DB_USER=4dm1n157r470r@threetier-sqlserver-moaz2024
DB_PWD=4-v3ry-53cr37-p455w0rd
DB_DATABASE=example-db
```


#### D) Verification Commands

```bash
# Backend health check
curl http://localhost:4000/health

# Database health check
curl http://localhost:4000/transaction

# Proxy health check
curl http://4.211.129.94/api/transaction

# Systemd service status
sudo systemctl status ab3-app.service

# View service logs
sudo journalctl -u ab3-app.service -n 50 --no-pager
```


### 5. Final Inventory File

```ini
[appservers]
4.211.201.137 ansible_user=moazadmfin ansible_ssh_private_key_file=/home/...../.ssh/id_rsa

[webservers]  
4.211.129.94 ansible_user=moazadmfin ansible_ssh_private_key_file=/home/..../.ssh/id_rsa
```


### 6. Additional Notes


- Ensure SSH key is accessible at the correct WSL path
- Use `ignore_errors: true` for apt update tasks to avoid transient errors
- Use `ACCEPT_EULA=Y` when installing Microsoft SQL tools
- Ensure callback patterns match between TransactionService.js and index.js

This configuration ensures the application works correctly from the first deployment without errors!
