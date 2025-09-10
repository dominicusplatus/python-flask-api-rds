variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Base domain name for DNS"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

# Applications Configuration
variable "applications" {
  description = "Map of application configurations"
  type = map(object({
    name                = string
    image_name          = optional(string, "public.ecr.aws/nginx/nginx")
    image_tag           = optional(string, "latest")
    port                = optional(number, 8080)
    cpu                 = optional(number, 1024)
    memory              = optional(number, 2048)
    desired_count       = optional(number, 1)
    min_capacity        = optional(number, 1)
    max_capacity        = optional(number, 3)
    target_cpu_percent  = optional(number, 70)

    # Environment variables for the container
    environment_variables = optional(map(string), {})

    rds_config = optional(object({
      engine                  = optional(string, "postgres")
      engine_version          = optional(string, "17.6")
      instance_class          = optional(string, "db.t3.small")
      allocated_storage       = optional(number, 100)
      max_allocated_storage   = optional(number, 1000)
      storage_encrypted       = optional(bool, true)
      multi_az                = optional(bool, false)
      backup_retention_period = optional(number, 30)
      backup_window           = optional(string, "01:00-02:00")
      maintenance_window      = optional(string, "Sun:02:00-Sun:03:00")
      deletion_protection     = optional(bool, false)
      skip_final_snapshot     = optional(bool, true)
    }), {})

    # Secrets from AWS Secrets Manager via ARNs
    secrets = optional(map(string), {})

    # ALB Access Control - optional per application
    allowed_cidr_blocks = list(string)
  }))
}
