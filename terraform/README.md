
## AWS Free Tier Note

The RDS configuration in this repository is production-grade and includes:
- 7-day backup retention
- Enhanced monitoring (60s interval)
- Performance Insights enabled
- Encrypted storage (gp3)

> **Note:** Full deployment requires an AWS account with RDS permissions
> beyond Free Tier limits. The Terraform code is valid and verified
> (`terraform validate` passes). To deploy on Free Tier, set:
> - `db_backup_retention_days = 1`
> - `monitoring_interval = 0`
> - `performance_insights_enabled = false`
>
> These are cost/tier constraints, not architectural limitations.
