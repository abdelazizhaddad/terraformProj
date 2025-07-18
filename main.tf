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

#create route table for public instamces
module "public_rt" {
  source = "./rt"
  name = "public_rt"
  vpc_id = module.main_vpc.vpc_id
  subnet_ids = [ module.public_subnet_a.subnet_id , module.public_subnet_b.subnet_id ]
  default_route_gateway_id = module.igw.internet_gateway_id
}

#create route table for public instamces
module "private_rt" {
  source = "./rt"
  name = "private_rt"
  vpc_id = module.main_vpc.vpc_id
  subnet_ids = [ module.private_subnet_a.subnet_id , module.private_subnet_b.subnet_id ]
  default_route_gateway_id  = module.ngw.nat_gateway_id
  use_internet_gateway      = false
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
  name = "external_alb"
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
  security_group_id = module.proxy_sg.security_group_id
  name = "proxy_server_a"
  associate_public_ip = true
  ami_id           = data.aws_ami.amazon_linux_2.id
}

#create proxy server b
module "proxy_server_b" {
  source = "./instance"
  subnet_id = module.public_subnet_b.subnet_id
  security_group_id = module.proxy_sg.security_group_id
  name = "proxy_server_b"
  associate_public_ip = true
  ami_id           = data.aws_ami.amazon_linux_2.id
}

#call nginx conf file 
data "template_file" "nginx_proxy_config" {
  template = file("${path.module}/nginx.conf.tpl")

  vars = {
    private_alb_dns_name = module.private_alb.lb_dns_name
  }
}

#proxy installation on proxy server a
resource "null_resource" "proxy_a_provisioner" {
  depends_on = [module.proxy_server_a]

  provisioner "file" {
    content     = data.template_file.nginx_proxy_config.rendered
    destination = "/tmp/nginx.conf"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("zizo.pem")
      host        = module.proxy_server_a.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo systemctl restart nginx"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("zizo.pem")
      host        = module.proxy_server_a.public_ip
    }
  }
}

#proxy installation on proxy server b
resource "null_resource" "proxy_b_provisioner" {
  depends_on = [module.proxy_server_b]

  provisioner "file" {
    content     = data.template_file.nginx_proxy_config.rendered
    destination = "/tmp/nginx.conf"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("zizo.pem")
      host        = module.proxy_server_b.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "sudo mv /tmp/nginx.conf /etc/nginx/nginx.conf",
      "sudo systemctl restart nginx"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("zizo.pem")
      host        = module.proxy_server_b.public_ip
    }
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
  name = "internal_alb"
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
  source = "./instance"
  subnet_id = module.private_subnet_a.subnet_id
  security_group_id = module.web_sg.security_group_id
  name = "web_server_a"
  ami_id           = data.aws_ami.amazon_linux_2.id
}

#creating wep server b
module "web_server_b" {
  source = "./instance"
  subnet_id = module.private_subnet_b.subnet_id
  security_group_id = module.web_sg.security_group_id
  name = "web_server_b"
  ami_id           = data.aws_ami.amazon_linux_2.id
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

#installing apache on web a
resource "null_resource" "web_a_provisioner" {
  depends_on = [module.web_server_a]

  provisioner "file" {
    source      = "./app/"
    destination = "/home/ec2-user/app"

    connection {
      type                = "ssh"
      user                = "ec2-user"
      private_key         = file("zizo.pem")
      host                = module.web_server_a.private_ip
      bastion_host        = module.proxy_server_a.public_ip
      bastion_user        = "ec2-user"
      bastion_private_key = file("zizo.pem")
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",
      "sudo mv /home/ec2-user/app/* /var/www/html/",
      "sudo chown -R apache:apache /var/www/html",
      "sudo systemctl restart httpd"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("zizo.pem")
      host        = module.web_server_a.private_ip

      bastion_host        = module.proxy_server_a.public_ip
      bastion_user        = "ec2-user"
      bastion_private_key = file("zizo.pem")
    }

  }
}

#installing apache on web b
resource "null_resource" "web_b_provisioner" {
  depends_on = [module.web_server_b]

  provisioner "file" {
    source      = "./app/"
    destination = "/home/ec2-user/app"

    connection {
      type                = "ssh"
      user                = "ec2-user"
      private_key         = file("zizo.pem")
      host                = module.web_server_b.private_ip
      bastion_host        = module.proxy_server_a.public_ip
      bastion_user        = "ec2-user"
      bastion_private_key = file("zizo.pem")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y httpd",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",
      "sudo mv /home/ec2-user/app/* /var/www/html/",
      "sudo chown -R apache:apache /var/www/html",
      "sudo systemctl restart httpd"
    ]


    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("zizo.pem")
      host        = module.web_server_b.private_ip

      bastion_host        = module.proxy_server_b.public_ip
      bastion_user        = "ec2-user"
      bastion_private_key = file("zizo.pem")
    }

  }
}

#storing  IPs locally
resource "null_resource" "write_all_ips" {
  depends_on = [
    module.proxy_server_a,
    module.proxy_server_b,
    module.web_server_a,
    module.web_server_b,
    module.ngw
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "public-ip1" > all-ips.txt
      echo "${module.proxy_server_a.public_ip}" >> all-ips.txt
      echo "public-ip2" >> all-ips.txt
      echo "${module.proxy_server_b.public_ip}" >> all-ips.txt
      echo "private-ip1" >> all-ips.txt
      echo "${module.web_server_a.private_ip}" >> all-ips.txt
      echo "private-ip2" >> all-ips.txt
      echo "${module.web_server_b.private_ip}" >> all-ips.txt
      echo "nat-gateway-eip" >> all-ips.txt
      echo "${module.ngw.nat_gateway_eip}" >> all-ips.txt
      EOT
  }
}

