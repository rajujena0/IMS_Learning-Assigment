# AWS Architecture Design

## Diagram
┌──────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│  ┌───────────────────────────────────────────────────────┐   │
│  │                  VPC (10.0.0.0/16)                    │   │
│  │                                                       │   │
│  │  ┌─────────────────────┐                              │   │
│  │  │  Public Subnet      │  ← ALB + NAT Gateway         │   │
│  │  │  10.0.1.0/24        │                              │   │
│  │  │  [ALB] [NAT GW]     │                              │   │
│  │  └──────────┬──────────┘                              │   │
│  │             │ (ALB SG only)                           │   │
│  │  ┌──────────▼──────────┐                              │   │
│  │  │  Private App Subnet │  ← EC2/ECS (no public IP)    │   │
│  │  │  10.0.10.0/24       │                              │   │
│  │  │  [EC2 App Server]   │  ← SSM Session Manager       │   │
│  │  └──────────┬──────────┘                              │   │
│  │             │ (Port 5432, App SG only)                │   │
│  │  ┌──────────▼──────────┐                              │   │
│  │  │  Private DB Subnets │  ← RDS (no internet route)   │   │
│  │  │  10.0.20.0/24 (AZ1) │                              │   │
│  │  │  10.0.21.0/24 (AZ2) │                              │   │
│  │  │  [RDS PostgreSQL]   │                              │   │
│  │  └─────────────────────┘                              │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  [Secrets Manager]  [CloudWatch]  [SSM]  [ECR]              │
└──────────────────────────────────────────────────────────────┘
Traffic: Internet → IGW → ALB → EC2 (private) → RDS (private)
Admin:   SSM Session Manager → EC2 (no SSH, no bastion)
CI/CD:   GitHub Actions → ECR → ECS Rolling Deploy

## Key Decisions

| Area | Decision | Reason |
|------|----------|--------|
| Admin access | SSM Session Manager | No port 22, IAM-controlled, audited |
| Secrets | AWS Secrets Manager | Auto-rotation, no hardcoded creds |
| DB placement | Private subnet, no internet route | Zero direct exposure |
| NAT Gateway | Single (dev) | Cost saving; add per-AZ for prod |
| Multi-AZ RDS | Off (dev) / On (prod) | Cost vs availability tradeoff |
| Monitoring | CloudWatch alarms on CPU + storage | Proactive alerting |
