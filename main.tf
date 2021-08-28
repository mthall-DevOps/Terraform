# The default provider configuration; resources that begin with `aws_` will use
# it as the default, and it can be referenced as `aws`.
#AWS crednetials
provider "aws" {
  region = "ap-south-1"
  access_key = "Accesskey from AWS"
  secret_key = "secret key from AWS"
}

#variable declaration
variable "subnet_prefix" {
  description = "cidr block for subnet"
  #default = 
  #type
} 
#VPC creation resource
resource "aws_vpc" "MY-VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "PROD"
  }
}
#subnet creation for VPC
resource "aws_subnet" "MY-VPC-subnet1" {
  vpc_id     = aws_vpc.MY-VPC.id
  cidr_block = var.subnet_prefix[0].cidr_block
  availability_zone = "ap-south-1b"

  tags = {
    Name = var.subnet_prefix[0].name
  }
}
#subnet-2
resource "aws_subnet" "MY-VPC-subnet2" {
  vpc_id     = aws_vpc.MY-VPC.id
  cidr_block = var.subnet_prefix[1].cidr_block
  availability_zone = "ap-south-1b"

  tags = {
    Name = var.subnet_prefix[1].name
  }
}
#Internet gateway to allow public traffic into VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.MY-VPC.id

}
#Route table to route the traffic
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.MY-VPC.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
    }
  route {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.gw.id
    } 
}
#Associate subnet with Route table 
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.MY-VPC-subnet1.id
  route_table_id = aws_route_table.rt.id
}
#security group with ports 22,443 and 80 open for webserver
resource "aws_security_group" "SG" {
  name        = "WEB-SERVER"
  description = "Allow Web traffic"
  vpc_id      = aws_vpc.MY-VPC.id
  ingress{
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress{
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress{
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  egress{
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  tags = {
    Name = "Wer-server-SG"
  }
}
#Network interface creation with an ip in the subnet 
resource "aws_network_interface" "webserver-nic" {
  subnet_id       = aws_subnet.MY-VPC-subnet1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.SG.id]
}
#elastic ip creation for network interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.webserver-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

# Output block to print the public ip on the console
output "server_public_ip" {
  value = aws_eip.one.public_ip
}

#EC2 instance resource of ubuntu 
resource "aws_instance" "MyVM1" {
  ami           = "ami-04bde106886a53080"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1b"
  key_name = "MyVM"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.webserver-nic.id
  }
  
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo welcome to Terraform > /var/www/html/index.html'
              EOF
   tags = {
    Name = "Web-Server"
  }
}


