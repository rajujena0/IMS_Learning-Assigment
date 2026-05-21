# DevOps Engineer Technical Assessment

## Architecture
See `architecture/DESIGN.md` for full diagram and decisions.

**Traffic flow:** `Internet → ALB (public) → EC2 (private) → RDS (private)`  
**Admin access:** SSM Session Manager — no SSH, no bastion, no port 22  
**Secrets:** AWS Secrets Manager — zero hardcoded credentials

## Structure
├── README.md
├── architecture/DESIGN.md      # Diagram + design decisions
├── terraform/                  # Part 2 — Infrastructure as Code
│   ├── main.tf                 # Provider + locals
│   ├── variables.tf            # All inputs
│   ├── outputs.tf              # Useful values post-apply
│   ├── vpc.tf                  # VPC, subnets, routing, NAT, VPC endpoints
│   ├── security_groups.tf      # Least-privilege SGs
│   ├── ec2.tf                  # EC2 + IAM role for SSM
│   ├── rds.tf                  # PostgreSQL + Secrets Manager + alarms
│   └── templates/user_data.sh  # EC2 bootstrap
└── scripts/health_check.sh     # Part 3 — Linux health monitoring

## Terraform Quick Start

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars (no secrets there — use env vars below)

export TF_VAR_db_username="appuser"
export TF_VAR_db_password="$(openssl rand -base64 20)"

terraform init
terraform plan
terraform apply
```

### Connect to EC2 (no SSH needed)
```bash
# After apply, use the printed command:
aws ssm start-session --target <instance-id> --region us-east-1
```

### Fetch DB credentials
```bash
aws secretsmanager get-secret-value \
  --secret-id webapp-dev/rds/credentials \
  --query SecretString --output text | jq .
```

## Health Check Script

```bash
chmod +x scripts/health_check.sh
sudo ./scripts/health_check.sh

# Exit 0 = healthy | 1 = disk critical (>80%) | 2 = warning
# Logs saved to: /var/log/health_check/YYYY-MM-DD_HH-MM-SS.log
```

### Cron setup
```bash
echo "*/5 * * * * root /path/to/health_check.sh" | sudo tee /etc/cron.d/health-check
```

## Assumptions
- Single NAT Gateway (dev cost saving; add per-AZ for prod HA)
- `db.t3.micro` / `t3.micro` — scale up for prod
- Multi-AZ RDS off for dev (`db_multi_az = true` for prod)
- Amazon Linux 2023 AMI (`ami-0c02fb55956c7d316` for us-east-1)

## Tradeoffs

| Decision | Dev | Prod |
|----------|-----|------|
| NAT Gateway | 1 (saves ~$32/mo) | 1 per AZ |
| RDS Multi-AZ | Off | On |
| Deletion protection | Off | On |
| Bastion host | None (SSM only) | None (SSM only) |
