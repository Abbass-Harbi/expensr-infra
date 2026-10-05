# ecs-service

Deploys a containerized service on Amazon ECS, including the task definition,
service, and load balancer wiring.

## Usage

```hcl
module "ecs_service" {
  source = "../../modules/ecs-service"
}
```
