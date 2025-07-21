# Ansible Inventory Configuration

This directory contains the Ansible inventory configuration for the 3-tier application deployment.

## Simple Approach

We use a **simple single-environment approach** with:
- **Static inventory**: `hosts.yml` (defines server groups)
- **Host variables**: `../host_vars/3-tier-app-server.yml` (server-specific configuration)

## Quick Setup

### Option 1: Manual Configuration

1. **Update host variables** with your server details:
   ```bash
   cp ../host_vars/3-tier-app-server.yml.example ../host_vars/3-tier-app-server.yml
   vim ../host_vars/3-tier-app-server.yml
   ```

2. **Update the key fields**:
   ```yaml
   ansible_host: "YOUR_SERVER_IP"
   ansible_ssh_private_key_file: ~/.ssh/your-key
   db_password: "YourSecurePassword"
   db_root_password: "YourSecureRootPassword"
   ```

### Option 2: Automatic Generation (from Terraform)

1. **Generate from Terraform outputs**:
   ```bash
   cd ../..  # Go to infrastructure-as-code directory
   ./generate-inventory.sh
   ```

2. **Review and customize** the generated file:
   ```bash
   vim ansible/host_vars/3-tier-app-server.yml
   ```

## File Structure

```
inventory/
├── hosts.yml                    # Static inventory (server groups)
└── README.md                   # This file

../host_vars/
├── 3-tier-app-server.yml      # Server-specific variables
└── 3-tier-app-server.yml.example  # Example configuration
```

## Testing Connectivity

```bash
# Test connection to your server
ansible all -i inventory/hosts.yml -m ping

# Check what variables are loaded
ansible-inventory -i inventory/hosts.yml --list --yaml
```

## Deployment

```bash
# Deploy the application
./deploy.sh

# Deploy with verbose output
./deploy.sh -v
```

## Key Variables to Customize

| Variable | Description | Example |
|----------|-------------|---------|
| `ansible_host` | Server public IP | `203.0.113.10` |
| `ansible_ssh_private_key_file` | SSH key path | `~/.ssh/3-tier-app` |
| `db_password` | Database password | `MySecurePassword123!` |
| `db_root_password` | MySQL root password | `MySecureRootPassword123!` |
| `nginx_server_name` | Domain name | `app.example.com` or `_` |
| `app_owner` | Contact email | `admin@example.com` |

## Security Notes

- **Change default passwords** in `host_vars/3-tier-app-server.yml`
- **Protect your SSH key**: `chmod 600 ~/.ssh/your-key`
- **Use Ansible Vault** for production passwords:
  ```bash
  ansible-vault encrypt_string 'MySecurePassword' --name 'db_password'
  ```

---

**Simple and straightforward!** No complex templating or multi-environment complexity. 🎯
