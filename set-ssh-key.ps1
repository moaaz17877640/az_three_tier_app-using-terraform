<#
Generates an SSH key pair at $env:USERPROFILE\.ssh\id_rsa (and .pub) if one does not already exist.
This helper is intended for local development so Ansible can connect to VMs created by Terraform.
DO NOT commit the private key to source control. If you expose the key, rotate access on the VM.
#>

param(
    [string]$PrivateKeyPath = "$env:USERPROFILE\.ssh\id_rsa",
    [switch]$Force
)

$publicKeyPath = "$PrivateKeyPath.pub"
$sshDir = Split-Path $PrivateKeyPath -Parent

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

if ((Test-Path $PrivateKeyPath -or Test-Path $publicKeyPath) -and (-not $Force)) {
    Write-Output "SSH keypair already exists."
    Write-Output "Private key: $PrivateKeyPath"
    Write-Output "Public key:  $publicKeyPath"
    Write-Output "Use -Force to overwrite."
    exit 0
}

# Generate RSA 4096 key without passphrase for automation
ssh-keygen -t rsa -b 4096 -f $PrivateKeyPath -N "" -q

if ($LASTEXITCODE -eq 0) {
    Write-Output "SSH keypair created."
    Write-Output "Private key: $PrivateKeyPath"
    Write-Output "Public key:  $publicKeyPath"
    Write-Output "Add the public key content to your Terraform var/VM or use the path: $publicKeyPath"
} else {
    Write-Error "ssh-keygen failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
