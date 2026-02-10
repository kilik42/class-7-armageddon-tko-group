#######################
# Bonus A
#######################


############################################
# Move EC2 into PRIVATE subnet (no public IP)
############################################

resource "aws_instance" "sao_ec2_private_b" {
  provider = aws.saopaulo
  ami                    = data.aws_ssm_parameter.sao_al2023.value
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.sao_private[0].id
  vpc_security_group_ids = [aws_security_group.sao_ec2pri_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.sao_iam_profile.name


  # tells Terraform to bootstrap the EC2 instance at first boot (and to recreate the instance if the script changes) 
  # so your target group health check can succeed.

user_data = file("user_dataprivate.sh")

  tags = {
    Name = "sao-ec2-private"
  }
}

############################################
# Security Group for VPC Interface Endpoints
############################################

resource "aws_security_group" "sao_ec2pri_sg" {
  provider = aws.saopaulo
  name        = "sao-ec2pri-sg"
  description = "SG for VPC Interface Endpoints"
  vpc_id      = aws_vpc.sao_main_vpc.id


  tags = {
    Name = "sao-ec2pri-sg"
  }
}

resource "aws_security_group" "sao_vpc_endpoints_sg" {
  provider    = aws.saopaulo
  name        = "sao-vpc-endpoints-sg"
  description = "Allow 443 to VPC interface endpoints only from private EC2 SG"
  vpc_id      = aws_vpc.sao_main_vpc.id

  tags = { Name = "sao-vpc-endpoints-sg" }
}

# Inbound 443 to the endpoints, but ONLY from the EC2 SG
resource "aws_vpc_security_group_ingress_rule" "sao_vpc_endpoints_in_443_from_ec2" {
  provider          = aws.saopaulo
  security_group_id = aws_security_group.sao_vpc_endpoints_sg.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  referenced_security_group_id = aws_security_group.sao_ec2pri_sg.id
}

# Egress can stay open (endpoints need to respond back to the instances)
resource "aws_vpc_security_group_egress_rule" "sao_vpc_endpoints_out_all" {
  provider          = aws.saopaulo
  security_group_id = aws_security_group.sao_vpc_endpoints_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


############################################
# VPC Endpoint - S3 (Gateway)
############################################


resource "aws_vpc_endpoint" "sao_ec2pri_s3_gw" {
  provider = aws.saopaulo
  vpc_id            = aws_vpc.sao_main_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.sao_current_region.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.sao_private_route.id
  ]

  tags = {
    Name = "sao-ec2pri-s3-gw"
  }
}


############################################
# VPC Endpoints - SSM (Interface)
############################################

locals {
  sao_endpoint_subnet_ids = aws_subnet.sao_private[*].id 
}

resource "aws_vpc_endpoint" "sao_ec2pri_ssm" {
  provider            = aws.saopaulo
  vpc_id              = aws_vpc.sao_main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.sao_current_region.region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.sao_endpoint_subnet_ids
  security_group_ids = [aws_security_group.sao_vpc_endpoints_sg.id]

  tags = { Name = "sao-vpce-ssm" }
}

resource "aws_vpc_endpoint" "sao_ec2pri_ec2messages" {
  provider            = aws.saopaulo
  vpc_id              = aws_vpc.sao_main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.sao_current_region.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.sao_endpoint_subnet_ids
  security_group_ids = [aws_security_group.sao_vpc_endpoints_sg.id]

  tags = { Name = "sao-vpce-ec2messages" }
}

resource "aws_vpc_endpoint" "sao_ec2pri_ssmmessages" {
  provider            = aws.saopaulo
  vpc_id              = aws_vpc.sao_main_vpc.id
  service_name        = "com.amazonaws.${data.aws_region.sao_current_region.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.sao_endpoint_subnet_ids
  security_group_ids = [aws_security_group.sao_vpc_endpoints_sg.id]

  tags = { Name = "sao-vpce-ssmmessages" }
}


############################################
# VPC Endpoint - CloudWatch Logs (Interface)
############################################

# resource "aws_vpc_endpoint" "ec2pri_logs" {
#   vpc_id              = aws_vpc.main_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current_region.region}.logs"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true

#   subnet_ids         = [aws_subnet.private[0].id]
#   security_group_ids = [aws_security_group.ec2pri_sg.id]

#   tags = {
#     Name = "ec2pri-logs"
#   }
# }


############################################
# VPC Endpoint - Secrets Manager (Interface)
############################################

# resource "aws_vpc_endpoint" "ec2pri_secrets" {
#   vpc_id              = aws_vpc.main_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current_region.region}.secretsmanager"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true

#   subnet_ids         = [aws_subnet.private[0].id]
#   security_group_ids = [aws_security_group.ec2pri_sg.id]

#   tags = {
#     Name = "ec2pri-secrets"
#   }
# }


############################################
# VPC Endpoint - KMS (Interface)
############################################

# resource "aws_vpc_endpoint" "ec2pri_kms" {
#   vpc_id              = aws_vpc.main_vpc.id
#   service_name        = "com.amazonaws.${data.aws_region.current_region.region}.kms"
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true

#   subnet_ids         = [aws_subnet.private[0].id]
#   security_group_ids = [aws_security_group.ec2pri_sg.id]

#   tags = {
#     Name = "ec2pri-kms"
#   }
# }
