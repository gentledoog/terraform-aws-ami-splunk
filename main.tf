provider "aws" {
  region = var.region
}

# Get Availability zones in the Region
data "aws_availability_zones" "US" {}

# Get My Public IP
data "http" "my_public_ip" {
  url = "https://ipinfo.io/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  public_ip = jsondecode(data.http.my_public_ip.response_body).ip
}

# Deploy a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "tf-example-2"
  }
}

# Deploy a IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Deploy a Subnet
resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.subnet
  availability_zone       = data.aws_availability_zones.US.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "my-subnet"
  }
}

# Deploy a network interface
resource "aws_network_interface" "network_interface" {
  subnet_id       = aws_subnet.my_subnet.id
  private_ips     = [var.private_ip]
  security_groups = [aws_security_group.splunk_sg.id]
  tags = {
    Name = "primary_network_interface"
  }
}

# Deploy a default route table and set default route to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_main_route_table_association" "association" {
  vpc_id         = aws_vpc.my_vpc.id
  route_table_id = aws_route_table.public.id
}

# Deploy the Splunk instance, with aforementioned network interface in the newly created VPC
data "aws_ami" "splunk" {
  most_recent = true
  #owners      = [""] ## Splunk Account 

  filter {
    name   = "name"
    values = ["splunk_AMI*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_instance" "splunk" {
  ami           = data.aws_ami.splunk.id
  instance_type = var.instance_type
  tags = {
    Name = "splunk-terraform"
  }
  network_interface {
    network_interface_id = aws_network_interface.network_interface.id
    device_index         = 0
  }
  availability_zone = data.aws_availability_zones.US.names[0]
}

output "splunk_public_ip" {
  value = aws_instance.splunk.public_ip
}

output "splunk_default_username" {
  value = "admin"
}

output "splunk_default_password" {
  value = "SPLUNK-${aws_instance.splunk.id}"
}

# Create a security group allowing access from your public IP address for UI and for API access and for access from the instance to Terraform Cloud 
#(it’s a PULL model: Splunk pulls the data from Terraform Cloud, towards the API IP range specified here and over port 443).
resource "aws_security_group" "splunk_sg" {
  name        = "Splunk SG"
  description = "Splunk Security Group"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "API Access"
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = ["${local.public_ip}/32"]
  }
  ingress {
    description = "UI Access"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["${local.public_ip}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ### To be more accurate, we could specify the Terraform Cloud public IP ranges used for API communications. 
    #Uncomment the line below and the ip_ranges datasource and public_ip_range locals if required.
    //cidr_blocks      = local.public_ip_range.api

    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "splunk_sg"
  }
}

# Get Terraform Cloud IP ranges
/*data "http" "ip_ranges" {
  url = "https://app.terraform.io/api/meta/ip-ranges"
  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  public_ip_range = jsondecode(data.http.ip_ranges.body)
}
*/
