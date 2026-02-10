data "aws_availability_zones" "sao_available" {
  provider = aws.saopaulo
  state    = "available"
}

locals {
  sao_azs = slice(data.aws_availability_zones.sao_available.names, 0, 3)
}

locals {
  sao_public_subnet_names = ["sao-public-1", "sao-public-2", "sao-public-3"]
}

###################
# VPC
###################

resource "aws_vpc" "sao_main_vpc" {
    provider = aws.saopaulo
  cidr_block           = var.sao_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "sao-main-vpc"
  }
}

###################
# igw
###################

resource "aws_internet_gateway" "sao_main_igw" {
    provider = aws.saopaulo
  vpc_id = aws_vpc.sao_main_vpc.id

  tags = {
    Name = "sao_main-igw"
  }
}

###################
# eip + nat
###################

resource "aws_eip" "sao_main_nat_eip" {
    provider = aws.saopaulo
  domain = "vpc"

  tags = {
    Name = "sao-nat-eip"
  }
}


resource "aws_nat_gateway" "sao_main_nat" {
    provider = aws.saopaulo
  allocation_id = aws_eip.sao_main_nat_eip.id
  subnet_id     = aws_subnet.sao_public[0].id

  tags = {
    Name = "sao-main-nat"
  }

  depends_on = [aws_internet_gateway.sao_main_igw]
}


#################################
# Subnets Public + Private
#################################

resource "aws_subnet" "sao_public" {
    provider = aws.saopaulo
  count = 3

  vpc_id                  = aws_vpc.sao_main_vpc.id
  cidr_block              = cidrsubnet(var.sao_vpc_cidr, 8, count.index + 1) # 10.80.1.0/24, 10.80.2.0/24, 10.80.3.0/24
  availability_zone       = local.sao_azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = local.sao_public_subnet_names[count.index]
  }
}

resource "aws_subnet" "sao_private" {
    provider = aws.saopaulo
  count = 3

  vpc_id                  = aws_vpc.sao_main_vpc.id
  cidr_block              = cidrsubnet(var.sao_vpc_cidr, 8, count.index + 11) # 11,12,13
  availability_zone       = local.sao_azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "sao-private-${count.index + 1}"
  }
}

#################################
# Route Tables
#################################

resource "aws_route_table" "sao_public_route" {
    provider = aws.saopaulo
  vpc_id = aws_vpc.sao_main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sao_main_igw.id
  }

  tags = {
    Name = "sao-public-route"
  }
}

resource "aws_route_table_association" "sao_public" {
    provider = aws.saopaulo
  count          = length(aws_subnet.sao_public)
  subnet_id      = aws_subnet.sao_public[count.index].id
  route_table_id = aws_route_table.sao_public_route.id
}

####Private####

resource "aws_route_table" "sao_private_route" {
    provider = aws.saopaulo
  vpc_id = aws_vpc.sao_main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.sao_main_nat.id
  }

  tags = {
    Name = "sao-private-route"
  }
}

resource "aws_route_table_association" "sao_private" {
    provider = aws.saopaulo
  count          = length(aws_subnet.sao_private)
  subnet_id      = aws_subnet.sao_private[count.index].id
  route_table_id = aws_route_table.sao_private_route.id
}


resource "aws_route" "armageddon_liberdade_to_tokyo_route01" {
  provider               = aws.saopaulo
  route_table_id         = aws_route_table.sao_private_route.id
  destination_cidr_block = "10.30.0.0/16" # Tokyo VPC CIDR (students supply)
  transit_gateway_id     = aws_ec2_transit_gateway.armageddon_liberdade_tgw01.id
}


resource "aws_security_group" "sao_ec2_lab_sg" {
  provider = aws.saopaulo
  name        = "sao-ec2-lab"
  description = "sg for http browser & ssh into"
  vpc_id      = aws_vpc.sao_main_vpc.id

  tags = {
    Name = "sao-ec2-lab-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "sao_ec2_lab_http" {
  provider = aws.saopaulo
  security_group_id = aws_security_group.sao_ec2_lab_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "sao_ec2_lab_ssh" {
  provider = aws.saopaulo
  security_group_id = aws_security_group.sao_ec2_lab_sg.id
  cidr_ipv4         = "192.159.210.72/32" 
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "sao_ec2_lab_outbound" {
  provider = aws.saopaulo
  security_group_id = aws_security_group.sao_ec2_lab_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


#################################
# EC2 Instance
#################################

data "aws_ssm_parameter" "sao_ec2_al2023" {
  provider = aws.saopaulo
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

resource "aws_instance" "sao_ec2_lab" {
  provider               = aws.saopaulo
  ami                    = data.aws_ssm_parameter.sao_ec2_al2023.value
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.sao_public[0].id
  vpc_security_group_ids = [aws_security_group.sao_ec2_lab_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.sao_iam_profile.name

  user_data = file("${path.module}/user_data.sh")

  tags = { Name = "sao-ec2-lab" }
}


#################################
# IAM Role + Instane Profile 
#################################

resource "aws_iam_role" "sao_ec2_role" {
  provider = aws.saopaulo
  name = "sao-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# resource "aws_iam_role_policy_attachment" "read_specific_secret" {
#   role      = aws_iam_role.ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
# }


data "aws_caller_identity" "sao_current" {provider = aws.saopaulo}
data "aws_region" "sao_current_region" {provider = aws.saopaulo}

resource "aws_iam_policy" "sao_ssm_managed_instance_core_custom" {
  provider = aws.saopaulo
  name        = "sao-ssm-managed-instance-core-custom"
  description = "Custom SSM Managed Instance Core permissions (SSM + ssmmessages + ec2messages)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetManifest",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      }
    ]
  })
}

# this will attach it to the role in the EC2
resource "aws_iam_role_policy_attachment" "sao_attach_ssm_core_custom" {
  provider = aws.saopaulo
  role       = aws_iam_role.sao_ec2_role.name
  policy_arn = aws_iam_policy.sao_ssm_managed_instance_core_custom.arn
}


resource "aws_iam_role_policy" "sao_ec2_describe_min" {
  provider = aws.saopaulo
  name = "sao-ec2-describe-min"
  role = aws_iam_role.sao_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeVpcs",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSubnets",
        "ec2:DescribeNetworkAcls",
        "ec2:DescribeTransitGateways",
        "ec2:DescribeTransitGatewayAttachments",
        "ec2:DescribeTransitGatewayRouteTables",
        "ec2:SearchTransitGatewayRoutes"
      ]
      Resource = "*"
    }]
  })
}


resource "aws_iam_instance_profile" "sao_iam_profile" {
  provider = aws.saopaulo
  name = "sao-iam-profile"
  role = aws_iam_role.sao_ec2_role.name
}


#################################
# Secret Manager
#################################

# resource "aws_secretsmanager_secret" "sao_lab_rds_mysql" {
#   name                    = "lab/rds/mysql"
#   recovery_window_in_days = 0

# }

# resource "aws_secretsmanager_secret_version" "sao_lab_rds_mysql" {
#   secret_id = aws_secretsmanager_secret.sao_lab_rds_mysql.id

#   secret_string = jsonencode({
#     username = var.db_username
#     password = var.db_password
#     host     = aws_db_instance.rds_lab_mysql.address
#     port     = aws_db_instance.rds_lab_mysql.port
#     dbname   = var.db_name
#   })
# }


###################################
# Parameter Store (SSM Parameters)
###################################

# resource "aws_ssm_parameter" "sao_armageddon_db_endpoint" {
#   name  = "lab-db-endpoint"
#   type  = "String"
#   value = aws_db_instance.sao_rds_lab_mysql.address

#   tags = {
#     Name = "param-db-endpoint"
#   }
# }

# resource "aws_ssm_parameter" "sao_armageddona_db_port" {
#   name  = "lab-db-port"
#   type  = "String"
#   value = tostring(aws_db_instance.sao_rds_lab_mysql.port)

#   tags = {
#     Name = "param-db-port"
#   }
# }

# resource "aws_ssm_parameter" "sao_armageddon_db_name" {
#   name  = "lab-db-name"
#   type  = "String"
#   value = var.db_name

#   tags = {
#     Name = "param-db-name"
#   }
# }


###################################
# CloudWatch Logs (Log Watch)
###################################

# resource "aws_cloudwatch_log_group" "rds_log_group" {
#   name              = "rds-app"
#   retention_in_days = 7

#   tags = {
#     Name = "rds-log-group"
#   }
# }

# resource "aws_cloudwatch_log_metric_filter" "rds_connection_error" {
#   name           = "rds-connection-error"
#   pattern        = "OperationalError"
#   log_group_name = aws_cloudwatch_log_group.rds_log_group.name

#   metric_transformation {
#     name      = "DBConnectionErrors"
#     namespace = "Lab/RDSApp"
#     value     = "1"
#   }
# }


###################################
# Custom Metric + Alarm
###################################

# resource "aws_cloudwatch_metric_alarm" "alarm_db_fail" {
#   alarm_name          = "alarm-db-fail"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = 1

#   metric_name = "DBConnectionErrors"
#   namespace   = "Lab/RDSApp"
#   period      = 60
#   statistic   = "Sum"
#   threshold   = 3

#   treat_missing_data = "notBreaching"

#   alarm_actions = [aws_sns_topic.lab_db_incidents.arn]

#   tags = { Name = "alarm-db-fail" }
# }


##############
# SNS
##############

# resource "aws_sns_topic" "lab_db_incidents" {
#   name = "db-incidents"
# }

# resource "aws_sns_topic_subscription" "db_incidents" {
#   topic_arn = aws_sns_topic.lab_db_incidents.arn
#   protocol  = "email"
#   endpoint  = var.sns_email_endpoint
# }