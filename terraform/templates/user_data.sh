#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Bootstrap started $(date) ==="

yum update -y
yum install -y docker jq aws-cli
systemctl start docker && systemctl enable docker
systemctl start amazon-ssm-agent && systemctl enable amazon-ssm-agent

# Fetch DB credentials from Secrets Manager at runtime (never hardcoded)
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "${secret_arn}" \
  --region "${aws_region}" \
  --query SecretString --output text)

mkdir -p /etc/app
cat > /etc/app/environment <<ENV
DATABASE_HOST=$(echo $SECRET | jq -r '.host')
DATABASE_PORT=5432
DATABASE_NAME=$(echo $SECRET | jq -r '.dbname')
DATABASE_USER=$(echo $SECRET | jq -r '.username')
DATABASE_PASSWORD=$(echo $SECRET | jq -r '.password')
ENV
chmod 600 /etc/app/environment

echo "=== Bootstrap completed $(date) ==="
