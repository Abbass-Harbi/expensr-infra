# rds-proxy

Configures an Amazon RDS Proxy in front of the database to pool connections
and improve resilience for serverless and bursty workloads.

## Usage

```hcl
module "rds_proxy" {
  source = "../../modules/rds-proxy"
}
```
