# About
This is a sample web api project for AWS ECS hosting with RDS DB.

## TODO
* structure project with per environment config/dirs (ecs module) or terragrunt setup
* refactor to use terraform-aws-modules/ecs module
* create CICD for terraform
* split network to assign separate vpc subnet per app
* use VPC endpoints
* add domain and https certificate to ALB
* create CICD for ECR build&push and ECS deployment
* multiple clusters (cluster per set of applications)