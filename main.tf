provider "aws" {
    region = "us-east-2"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type{}
variable public_key_location {}
variable private_key_location {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

/*resource "aws_route_table" "myapp_route_table" {
  vpc_id = aws_vpc.myapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id 
  }
  tags = {
    Name: "${var.env_prefix}-rtb"
  }
}*/

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

/*resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id = aws_subnet.myapp_subnet-1.id 
  route_table_id = aws_route_table.myapp_route_table.id 
}*/

resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id 
  }
  tags = {
    Name: "${var.env_prefix}-main-rtb"
  }
}
# Security group rules

/*resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name: "${var.env_prefix}-sg"
  }

}*/

# Using the default security group

resource "aws_default_security_group" "default-sg" {
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name: "${var.env_prefix}-default-sg"
  }

}

# Configuration for creating EC2 Instance

data "aws_ami" "latest-amazon-linux-image" {
    most_recent = true
    owners = [ "amazon" ]
    filter {
        name = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    
}
# Quary the ami ID and output it
# # aim is dynamic and can change. So it is best to fetch it from AWS using data type

output "aws_aim_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}



# Automate ssh key pair
resource "aws_key_pair" "ssh-key" {
  key_name = "Demo-Private-KP2"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp1-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id  
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone = var.avail_zone

# Run user data in server to update server, install docker and install nginx
/*  user_data = <<EOF
                #!/bin/bash
                sudo yum update -y && sudo yum install -y docker
                sudo systemctl start docker
                sudo usermod -aG docker ec2-user
                docker run -p 8080:80 nginx
            EOF */
# You can also run user data by referencing a file that contains a script
#user_data = file("entry-script.sh")

# Executing remote provisioner to help terraform do configuration management
connection {
  type = "ssh"
  host = self.public_ip
  user = "ec2-user"
  private_key = file(var.private_key_location)
 
}

provisioner "file" {
  soruce = "entry-script.sh"
  destination = "/home/ec2-user/entry-script-on-ec2.sh"
}

provisioner "remote-exec" {
  soruce = file("entry-script-on-ec2.sh")
}

provisioner "local-exec" {
  command = "echo ${self.public_ip} > output.txt"
}

/*provisioner "remote-exec" {
  inline = [
    "export ENV=dev",
    "mkdir newdir"
  ]
}*/

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  tags = {
    Name = "${var.env_prefix}-server"
  }
}

# Output to print public IP
output "ec2_public_ip" {
  value = aws_instance.myapp1-server.public_ip
}
