# VProfile Terraform deployment

This directory replaces the sequential `VPC.sh`, `backend.sh`, `frontend_1.sh`, and `frontend_2.sh` flow with one declarative GCP stack. It provisions the VPC, private service access, Cloud SQL, Memcached, private DNS, bastion, application MIG with autoscaling, global load balancing, and optional Google-managed HTTPS.

The old golden-VM/snapshot flow is intentionally removed. Each managed instance builds the pinned Git branch during startup, which makes replacement and scale-out instances reproducible without a twelve-minute shell sleep or manually-created image.

## Deploy

1. Authenticate with Application Default Credentials and enable billing on the target project.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and replace every placeholder. Keep `terraform.tfvars` out of source control because it contains the database password and SSH key.
3. Run:

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

4. Before applying with `enable_https = true`, create the `certificate_dns_record` output as a CNAME at the registrar for `domain`. Google will only activate the certificate after that record propagates.
5. The application instances initialize the `accounts` database from `db_backup.sql` after Cloud SQL becomes reachable. Inspect `/var/log/vprofile-startup.log` on an app VM if startup takes time.

## Destroy

Terraform is the rollback mechanism:

```powershell
terraform destroy
```

Cloud SQL deletion protection is disabled so destroy removes the same resources that the old rollback script attempted to remove. The `google_service_networking_connection` uses `deletion_policy = "ABANDON"` to avoid deleting shared service networking infrastructure accidentally; remove that setting only when the project is dedicated to this stack.

## Security notes

Use Secret Manager or a CI/CD secret variable for `db_password` in production instead of committing a tfvars file. Restrict `admin_cidr` to the operator's current public IP, and use a dedicated service account with least-privilege scopes rather than the broad bootstrap scope when hardening the deployment.