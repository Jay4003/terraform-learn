provider "aws" {
#    region = "us-east-2"
}

variable avail_zone {}

variable "cidr_block" {
  description = "cidr blocks and name tags for vpc and subnets"
  type = list(object({
    cidr_block = string
    name = string
  })) 

}

#variable "vpc_cidr_block" {
#    description = "subnet cidr block"
#}

variable "enviroment" {
  description = "deployment enviroment"
}

resource "aws_vpc" "dev-vpc" {
  cidr_block = var.cidr_block[0].cidr_block
  tags = {
    Name: var.cidr_block[0].name
    
  }
}
resource "aws_subnet" "dev-subnet-1" {
  vpc_id = aws_vpc.dev-vpc.id
  cidr_block = var.cidr_block[1].cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name: var.cidr_block[1].name
  }
}

data "aws_vpc" "existing_vpc" {
  default = true
}
resource "aws_subnet" "dev-subnet-2" {
  vpc_id = data.aws_vpc.existing_vpc.id
  cidr_block = "172.31.48.0/20"
  availability_zone = "us-east-2a"
  tags = {
    Name: "subnet-1-default"
  }
}
output "dev-vpc-id" {
    value = aws_vpc.dev-vpc.id
  
}
output "dev-subnet-id" {
    value = aws_subnet.dev-subnet-1.id
}


