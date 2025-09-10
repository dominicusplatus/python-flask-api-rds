# Project Configuration
project     = "myapp"
environment = "dev"
aws_region  = "eu-west-1"
domain_name = "testapi.example.com"

# Common Tags
tags = {
  Project     = "myapp"
  Environment = "dev"
  ManagedBy   = "terraform"
  Owner       = "DevOps Team"
}

# Applications Configuration
applications = {
  "api-service" = {
    name       = "api-service"
    image_name = "266280837669.dkr.ecr.eu-west-1.amazonaws.com/myapp-dev-api-service"
    image_tag  = "06e049661300278d0f9395b2ba92b496336700bf"

    # Container Configuration
    port          = 8080
    cpu           = 1024
    memory        = 2048
    desired_count = 1

    # ALB Access Control
    allowed_cidr_blocks = [
      "75.2.60.0/24",
      "46.205.198.163/32"
    ]
  }
}