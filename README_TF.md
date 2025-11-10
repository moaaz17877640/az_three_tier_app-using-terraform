Using variables for Azure provider authentication

This directory configures Azure resources with Terraform. To avoid committing secrets to the repository, provider credentials should be supplied at runtime via environment variables or a secure tfvars file (and not committed).

Preferred (local / CI-safe): Use environment variables

PowerShell (temporary in current session):

```powershell
$Env:ARM_SUBSCRIPTION_ID = "<subscription-id>"
$Env:ARM_TENANT_ID       = "<tenant-id>"
$Env:ARM_CLIENT_ID       = "<client-id>"
$Env:ARM_CLIENT_SECRET   = "<client-secret>"
```

To persist values in Windows user environment (requires reopening shell):

```powershell
setx ARM_SUBSCRIPTION_ID "<subscription-id>"
setx ARM_TENANT_ID "<tenant-id>"
setx ARM_CLIENT_ID "<client-id>"
setx ARM_CLIENT_SECRET "<client-secret>"
```

Or supply a `terraform.tfvars` file (not recommended to commit):

- Copy `terraform.tfvars.example` -> `terraform.tfvars` and fill values.
- Run `terraform init` and `terraform plan`.

Notes and recommendations

- DO NOT commit `terraform.tfvars` with real secrets.
- In CI (GitHub Actions / Azure DevOps), store the four values as secure pipeline secrets and map them to the ARM_* environment variables during the job.
- You can also use managed identities (if running in Azure) and avoid client secrets entirely.
- If you accidentally committed credentials, rotate/delete the service principal immediately.
