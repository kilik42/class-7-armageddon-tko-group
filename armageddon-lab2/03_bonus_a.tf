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
  vpc_security_group_ids = [aws_security_group.ec2pri_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.iam_profile.name


  # tells Terraform to bootstrap the EC2 instance at first boot (and to recreate the instance if the script changes) 
  # so your target group health check can succeed.

user_data = file("user_dataprivate.sh")

  tags = {
    Name = "ec2-private"
  }
}
############################################
# Security Group for VPC Interface Endpoints
############################################

resource "aws_security_group" "ec2pri_sg" {
  name        = "ec2pri-sg"
  description = "SG for VPC Interface Endpoints"
  vpc_id      = aws_vpc.main_vpc.id


  tags = {
    Name = "ec2pri-sg"
  }
}


resource "aws_vpc_security_group_ingress_rule" "ec2pri_int" {
  security_group_id = aws_security_group.ec2pri_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

############################################
# VPC Endpoint - S3 (Gateway)
############################################


resource "aws_vpc_endpoint" "ec2pri_s3_gw" {
  vpc_id            = aws_vpc.main_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current_region.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_route.id
  ]

  tags = {
    Name = "ec2pri-s3-gw"
  }
}


############################################
# VPC Endpoints - SSM (Interface)
############################################

resource "aws_vpc_endpoint" "ec2pri_ssm" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.ec2pri_sg.id]


  tags = {
    Name = "ec2pri-ssm"
  }
}

resource "aws_vpc_endpoint" "ec2pri_ec2messages" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.ec2pri_sg.id]


  tags = {
    Name = "ec2pri-ec2messages"
  }
}


resource "aws_vpc_endpoint" "ec2pri_ssmmessages" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.ec2pri_sg.id]


  tags = {
    Name = "vpcend-ssmmessages"
  }
}


############################################
# VPC Endpoint - CloudWatch Logs (Interface)
############################################

resource "aws_vpc_endpoint" "ec2pri_logs" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.ec2pri_sg.id]

  tags = {
    Name = "ec2pri-logs"
  }
}


############################################
# VPC Endpoint - Secrets Manager (Interface)
############################################

resource "aws_vpc_endpoint" "ec2pri_secrets" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.ec2pri_sg.id]

  tags = {
    Name = "ec2pri-secrets"
  }
}


############################################
# VPC Endpoint - KMS (Interface)
############################################

resource "aws_vpc_endpoint" "ec2pri_kms" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = [aws_subnet.private[0].id]
  security_group_ids = [aws_security_group.ec2pri_sg.id]

  tags = {
    Name = "ec2pri-kms"
  }
}
