#vpc create 
module "main_vpc" {
  source = "./vpc"
  cidr_vpc = "10.0.0.0/16"
  name= "main_vpc"
}

#subnets

#public subnet az a create
module "public_subnet_a" {
  source = "./subnet"
  cidr_sub = "10.0.0.0/24"
  az = "us-east-1a"
  name = "public_subnet_a"
  vpc_id = module.main_vpc.vpc_id
  map_public_ip_on_launch = true
}

#public subnet az b create
module "public_subnet_b" {
  source = "./subnet"
  cidr_sub = "10.0.2.0/24"
  az = "us-east-1b"
  name = "public_subnet_b"
  vpc_id = module.main_vpc.vpc_id
  map_public_ip_on_launch = true
}

#private subnet az a create
module "private_subnet_a" {
  source = "./subnet"
  cidr_sub = "10.0.1.0/24"
  az = "us-east-1a"
  name = "private_subnet_a"
  vpc_id = module.main_vpc.vpc_id
}

#private subnet az b create
module "private_subnet_b" {
  source = "./subnet"
  vpc_id = module.main_vpc.vpc_id  
  cidr_sub = "10.0.3.0/24"
  az = "us-east-1b"
  name = "private_subnet_b"
  
}

#create internet gateway
module "igw" {
  source = "./gw"
  name = "igw"
  vpc_id = module.main_vpc.vpc_id
}

#create NAT gatway
module "ngw" {
  source = "./natgw"
  name = "natGW"
  public_subnet_id = module.public_subnet_a.subnet_id
}

#public_rt
module "public_rt" {
  source = "./rt"
  name   = "public_rt"
  vpc_id = module.main_vpc.vpc_id
  default_route_gateway_id = module.igw.internet_gateway_id
}

#private_rt
module "private_rt" {
  source = "./rt"
  name   = "private_rt"
  vpc_id = module.main_vpc.vpc_id
  default_route_gateway_id = module.ngw.nat_gateway_id
  use_internet_gateway     = false
}

# Public subnet associations
resource "aws_route_table_association" "public_a" {
  subnet_id      = module.public_subnet_a.subnet_id
  route_table_id = module.public_rt.route_table_id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = module.public_subnet_b.subnet_id
  route_table_id = module.public_rt.route_table_id
}

# Private subnet associations
resource "aws_route_table_association" "private_a" {
  subnet_id      = module.private_subnet_a.subnet_id
  route_table_id = module.private_rt.route_table_id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = module.private_subnet_b.subnet_id
  route_table_id = module.private_rt.route_table_id
}

#create security group for public alb
module "public_alb_sg" {
  source = "./secgroup"
  name        = "public_alb_sg"
  description = "security group for public alb"
  vpc_id      = module.main_vpc.vpc_id
  ingress_rules = [ 
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
   ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}


#create Application load balancer external
module "public_alb" {
  source = "./alb"
  name = "external-alb"
  vpc_id = module.main_vpc.vpc_id
  subnets = [module.public_subnet_a.subnet_id , module.public_subnet_b.subnet_id]
  security_groups = [ module.public_alb_sg.security_group_id ]
  
}

#create security group for proxy servers
module "proxy_sg" {
  source = "./secgroup"
  name        = "proxy_sg"
  description = "security group for proxy servers"
  vpc_id      = module.main_vpc.vpc_id
  ingress_rules = [ 
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      source_security_group_id = module.public_alb_sg.security_group_id
      
    } , 
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ "0.0.0.0/0" ]
    }
   ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

}

#create proxy server a
module "proxy_server_a" {
  source = "./instance"
  subnet_id = module.public_subnet_a.subnet_id
  security_group_id = [module.proxy_sg.security_group_id]
  name = "proxy_server_a"
  associate_public_ip = true
  ami_id           = data.aws_ami.amazon_ami.id

}

resource "null_resource" "provisionforproxya" {
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("zizo.pem")
    host        = module.proxy_server_a.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo amazon-linux-extras enable nginx1",
      "sudo yum install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "sudo bash -c 'cat > /etc/nginx/conf.d/reverse-proxy.conf <<EOT\nserver {\n    listen 80;\n    location / {\n        proxy_pass http://${module.private_alb.lb_dns_name}/;\n        proxy_set_header Host \\$host;\n        proxy_set_header X-Real-IP \\$remote_addr;\n        proxy_set_header X-Forwarded-For \\$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto \\$scheme;\n    }\n}\nEOT'",
      "sudo nginx -t",
      "sudo systemctl reload nginx"
    ]
  }
}


#create proxy server b
module "proxy_server_b" {
  source = "./instance"
  subnet_id = module.public_subnet_b.subnet_id
  security_group_id = [module.proxy_sg.security_group_id]
  name = "proxy_server_b"
  associate_public_ip = true
  ami_id           = data.aws_ami.amazon_ami.id

 
}

resource "null_resource" "provisionforproxyb" {
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("zizo.pem")
    host        = module.proxy_server_b.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo amazon-linux-extras enable nginx1",
      "sudo yum install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "sudo bash -c 'cat > /etc/nginx/conf.d/reverse-proxy.conf <<EOT\nserver {\n    listen 80;\n    location / {\n        proxy_pass http://${module.private_alb.lb_dns_name}/;\n        proxy_set_header Host \\$host;\n        proxy_set_header X-Real-IP \\$remote_addr;\n        proxy_set_header X-Forwarded-For \\$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto \\$scheme;\n    }\n}\nEOT'",
      "sudo nginx -t",
      "sudo systemctl reload nginx"
    ]
  }
}


#public alb attaching to proxy a
resource "aws_lb_target_group_attachment" "proxy_a" {
  target_group_arn = module.public_alb.target_group_arn
  target_id        = module.proxy_server_a.instance_id
  port             = 80
}

#public alb attaching to proxy b
resource "aws_lb_target_group_attachment" "proxy_b" {
  target_group_arn = module.public_alb.target_group_arn
  target_id        = module.proxy_server_b.instance_id
  port             = 80
}

#create security group for private alb
module "private_alb_sg" {
  source = "./secgroup"
  name        = "private_alb_sg"
  description = "security group for private alb"
  vpc_id      = module.main_vpc.vpc_id
  ingress_rules = [ 
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      source_security_group_id = module.proxy_sg.security_group_id
    } 
  ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}


#create Application load balancer internal
module "private_alb" {
  source = "./alb"
  name = "insidealb"
  vpc_id = module.main_vpc.vpc_id
  subnets = [module.private_subnet_a.subnet_id , module.private_subnet_b.subnet_id]
  security_groups = [ module.private_alb_sg.security_group_id ]
  internal = true
  
}

#create security group for web servers
module "web_sg" {
  source = "./secgroup"
  name        = "web_sg"
  description = "security group for web servers"

  vpc_id      = module.main_vpc.vpc_id
  ingress_rules = [ 
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      source_security_group_id = module.private_alb_sg.security_group_id
    }, 
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      source_security_group_id = module.proxy_sg.security_group_id
    }
   ]
  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

}

#creating wep server a
module "web_server_a" {
  source = "./web"
  subnet_id = module.private_subnet_a.subnet_id
  security_group_id = [module.web_sg.security_group_id]
  name = "web_server_a"
  ami_id           = data.aws_ami.amazon_ami.id

  
}



#creating wep server b
module "web_server_b" {
  source = "./web"
  subnet_id = module.private_subnet_b.subnet_id
  security_group_id = [module.web_sg.security_group_id]
  name = "web_server_b"
  ami_id           = data.aws_ami.amazon_ami.id

  
}



##private alb attaching to web a
resource "aws_lb_target_group_attachment" "web_a" {
  target_group_arn = module.private_alb.target_group_arn
  target_id        = module.web_server_a.instance_id
  port             = 80
}

##private alb attaching to web b
resource "aws_lb_target_group_attachment" "web_b" {
  target_group_arn = module.private_alb.target_group_arn
  target_id        = module.web_server_b.instance_id
  port             = 80
}


#storing  IPs locally
/* resource "null_resource" "write_all_ips" {
  depends_on = [
    module.proxy_server_a,
    module.proxy_server_b,
    module.web_server_a,
    module.web_server_b,
    module.ngw
  ]
   }
 /* provisioner "local-exec" {
    command = <<EOT
      echo "public-ip1" > all-ips.txt
      echo "${module.proxy_server_a.public_ip}" >> all-ips.txt
      echo "public-ip2" >> all-ips.txt
      echo "${module.proxy_server_b.public_ip}" >> all-ips.txt
      echo "private-ip1" >> all-ips.txt
      echo "${module.web_server_a.private_ip}" >> all-ips.txt
      echo "private-ip2" >> all-ips.txt
      echo "${module.web_server_b.private_ip}" >> all-ips.txt
      EOT
  }
}
*/
