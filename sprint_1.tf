#Exoscale provider configuration
terraform {
  required_providers {
    exoscale = {
      source  = "terraform-providers/exoscale"
    }
  }
}

variable "exoscale_key" {
  description = "The Exoscale API key"
  type = string
}
variable "exoscale_secret" {
  description = "The Exoscale API secret"
  type = string
}
provider "exoscale" {
  key = var.exoscale_key
  secret = "${var.exoscale_secret}"
}

#Security group configuration
resource "exoscale_security_group" "sg" {
  name = "project"
}

resource "exoscale_security_group_rule" "rule_1" {
  security_group_id = exoscale_security_group.sg.id
  type              = "INGRESS"
  protocol          = "tcp"
  cidr              = "0.0.0.0/0"
  start_port        = 8080
  end_port          = 8080
}

resource "exoscale_security_group_rule" "rule_2" {
  security_group_id = exoscale_security_group.sg.id
  type              = "INGRESS"
  protocol          = "tcp"
  cidr              = "0.0.0.0/0"
  start_port        = 22
  end_port          = 22
}

resource "exoscale_security_group_rule" "rule_3" {
  security_group_id = exoscale_security_group.sg.id
  type              = "INGRESS"
  protocol          = "tcp"
  user_security_group = exoscale_security_group.sg.name
  start_port        = 1
  end_port          = 65535
}

#Instance pool configuration - docker installation in userdata script to simply run load generator
data "exoscale_compute_template" "instance" {
  zone = "at-vie-1"
  name = "Linux Ubuntu 20.04 LTS 64-bit"
}

resource "exoscale_instance_pool" "instancepool-project" {
  name               = "instancepool-project"
  description        = "Instance pool for the project work"
  template_id        = data.exoscale_compute_template.instance.id
  service_offering   = "micro"
  size               = 2
  disk_size          = 10
  zone               = "at-vie-1"
  security_group_ids = [exoscale_security_group.sg.id]
  user_data          = <<EOF
#!/bin/bash

# setting to avoid configuration prompts
export DEBIAN_FRONTEND=noninteractive

# convenience script for docker installation - source: https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Run the load generator through docker - source: https://github.com/FH-Cloud-Computing/http-load-generator
docker run -d \
  --restart=always \
  -p 8080:8080 \
  janoszen/http-load-generator:1.0.1
EOF
}

#Network Load Balancer configuration
resource "exoscale_nlb" "project-nlb" {
  name        = "project-nlb"
  description = "Network Load Balancer for the project work"
  zone        = "at-vie-1"
}

resource "exoscale_nlb_service" "project-nlb-service" {
  zone             = exoscale_nlb.project-nlb.zone
  name             = "project-nlb-service"
  description      = "Network Load Balancer service"
  nlb_id           = exoscale_nlb.project-nlb.id
  instance_pool_id = exoscale_instance_pool.instancepool-project.id
  protocol         = "tcp"
  port             = 80
  target_port      = 8080
  strategy         = "round-robin"

  healthcheck {
    port     = 8080
    mode     = "http"
    uri      = "/health"
    interval = 10
    timeout  = 5
    retries  = 1
  }
}
