resource "aws_instance" "ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  security_groups             = var.security_group_id
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  
  tags = {
    Name = var.name
  }

  user_data = <<EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl enable httpd
    systemctl start httpd

    cat <<EOT > /var/www/html/index.html
    <!DOCTYPE html>
    <html>
    <head>
        <title>Terraform web project</title>
    </head>
    <body>
        <h1>Hello from Apache</h1>
        <p>This is Abdelaziz web server</p>
        <p>Hostname: $(hostname)</p>
    </body>
    </html>
    EOT
    EOF
}