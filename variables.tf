variable "region" { default = "us-west-1" }
variable "availability_zone" { default = "us-west-1a" }
variable "instance_type" { default = "t3.micro" }
variable "private_ip" { default = "172.16.10.100" }
variable "subnet" { default = "172.16.10.0/24" }
variable "vpc_cidr" { default = "172.16.0.0/16" }