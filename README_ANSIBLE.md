Generating an SSH key and using it with Ansible

1) Generate the keypair locally (PowerShell)

Open PowerShell and run from this directory:

```powershell
cd .\application-code\Infrasture_as_code_implementation
.\set-ssh-key.ps1
```

This creates:
- Private key: C:\Users\<you>\.ssh\id_rsa
- Public key:  C:\Users\<you>\.ssh\id_rsa.pub

2) Use the public key with Terraform
- Option A: Pass the public key path to Terraform when planning/applying:

```powershell
terraform plan -var "ssh_pub_key_path=$env:USERPROFILE\.ssh\id_rsa.pub"
terraform apply -var "ssh_pub_key_path=$env:USERPROFILE\.ssh\id_rsa.pub"
```

- Option B: Copy the public key content into the Terraform variable expected by your configuration (or update your `main.tf` to use the path above).

3) Use the private key with Ansible
- Example inventory (see `ansible/hosts.ini.example`) — set `ansible_ssh_private_key_file` to the private key path.
- Run the playbook (example):

```powershell
cd .\application-code\Infrasture_as_code_implementation\ansible
ansible-playbook -i hosts.ini playbook.yml --private-key C:/Users/<you>/.ssh/id_rsa
```

Security reminders
- Never commit private keys. Add `.ssh/id_rsa` or your local key paths to your repo-level `.gitignore` if you put helper scripts nearby.
- For production, prefer centrally managed secrets/keys (Key Vault, Secrets Manager) or use cloud-native key injection mechanisms.
