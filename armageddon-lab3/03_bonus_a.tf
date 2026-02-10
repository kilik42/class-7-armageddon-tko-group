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
  vpc_security_group_ids = [aws_security_group.ec2_private_sg.id]
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

resource "aws_security_group" "ec2_private_sg" {
  name        = "ec2-private-sg"
  description = "Private app instance SG (HTTP only from ALB)"
  vpc_id      = aws_vpc.main_vpc.id

  tags = { Name = "ec2-private-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_private_from_alb_http" {
  security_group_id            = aws_security_group.ec2_private_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_private_all_out" {
  security_group_id = aws_security_group.ec2_private_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Interface endpoints SG (443 only from private EC2)"
  vpc_id      = aws_vpc.main_vpc.id

  tags = { Name = "vpc-endpoints-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_from_ec2_private_443" {
  security_group_id            = aws_security_group.vpc_endpoints_sg.id
  referenced_security_group_id = aws_security_group.ec2_private_sg.id
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoints_all_out" {
  security_group_id = aws_security_group.vpc_endpoints_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_from_ec2_lab_443" {
  security_group_id            = aws_security_group.vpc_endpoints_sg.id
  referenced_security_group_id = aws_security_group.ec2_lab_sg.id
  from_port = 443
  to_port   = 443
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "tokyo_ec2_private_from_sao_http" {
  security_group_id = aws_security_group.ec2_private_sg.id
  cidr_ipv4         = "10.80.0.0/16"  # Sao Paulo VPC CIDR
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
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

locals {
  # Use at least 2 private subnets (2 AZs). If you have 3 AZs, keep 3.
  tokyo_endpoint_subnet_ids = aws_subnet.private[*].id
  tokyo_tgw_attach_subnet_ids = slice(aws_subnet.private[*].id, 0, 2)
}


resource "aws_vpc_endpoint" "ec2pri_ssm" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = local.tokyo_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]


  tags = {
    Name = "ec2pri-ssm"
  }
}

resource "aws_vpc_endpoint" "ec2pri_ec2messages" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = local.tokyo_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]


  tags = {
    Name = "ec2pri-ec2messages"
  }
}


resource "aws_vpc_endpoint" "ec2pri_ssmmessages" {
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.current_region.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = local.tokyo_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]


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

  subnet_ids = local.tokyo_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]

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

  subnet_ids = local.tokyo_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]

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

  subnet_ids = local.tokyo_endpoint_subnet_ids
  security_group_ids = [aws_security_group.vpc_endpoints_sg.id]

  tags = {
    Name = "ec2pri-kms"
  }
}
