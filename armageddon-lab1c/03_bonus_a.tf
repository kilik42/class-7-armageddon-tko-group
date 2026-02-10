#######################
# Bonus A
#######################


############################################
# Move EC2 into PRIVATE subnet (no public IP)
############################################

resource "aws_instance" "ec2_private_b" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.vpcend_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.iam_profile.name

# tells Terraform to bootstrap the EC2 instance at first boot (and to recreate the instance if the script changes) 
# so your target group health check can succeed.
  user_data_replace_on_change = true
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf -y install nginx
    echo "armageddon target OK" > /usr/share/nginx/html/index.html

    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = {
    Name = "ec2-private"
  }
}


############################################
# Security Group for VPC Interface Endpoints
############################################

resource "aws_security_group" "vpcend_sg" {
  name        = "vpcend-sg"
  description = "SG for VPC Interface Endpoints"
  vpc_id      = aws_vpc.main_vpc.id


  tags = {
    Name = "vpcend-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpcend_int" {
  security_group_id = aws_security_group.vpcend_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "vpcend_outbound" {
  security_group_id = aws_security_group.vpcend_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


############################################
# VPC Endpoint - S3 (Gateway)
############################################


resource "aws_vpc_endpoint" "vpcend_s3_gw" {
  vpc_id      = aws_vpc.main_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current_region.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_route.id
  ]

  tags = {
    Name = "vpcend-s3-gw"
  }
}


############################################
# VPC Endpoints - SSM (Interface)
############################################

resource "aws_vpc_endpoint" "vpcend_ssm" {
  vpc_id      = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.vpcend_sg.id]

  tags = {
    Name = "vpcend-ssm"
  }
}

resource "aws_vpc_endpoint" "vpcend_ec2messages" {
  vpc_id      = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.vpcend_sg.id]

  tags = {
    Name = "vpcend-ec2messages"
  }
}


resource "aws_vpc_endpoint" "vpcend_ssmmessages" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.vpcend_sg.id]

  tags = {
    Name = "vpcend-ssmmessages"
  }
}


############################################
# VPC Endpoint - CloudWatch Logs (Interface)
############################################

resource "aws_vpc_endpoint" "vpcend_logs" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.vpcend_sg.id]

  tags = {
    Name = "vpcend-logs"
  }
}


############################################
# VPC Endpoint - Secrets Manager (Interface)
############################################

resource "aws_vpc_endpoint" "vpcend_secrets" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.vpcend_sg.id]

  tags = {
    Name = "vpcend-secrets"
  }
}


############################################
# VPC Endpoint - KMS (Interface)
############################################

resource "aws_vpc_endpoint" "vpcend_kms" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.vpcend_sg.id]

  tags = {
    Name = "vpcend-kms"
  }
}
