# locals {
#   name_prefix = var.project_name
# }

locals {
  public_subnet_names = ["public-a", "public-b", "public-c"]
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}


##########
# Note
##########

# slice takes a chunk of a list Ex. slice(["a","b","c","d"], 0, 3) = ["a","b","c"]

# start = where to begin (0-based)
# end = where to stop (end is NOT included)

# data block is how you read / look up existing information instead of creating something new.

###################
# VPC
###################

resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

###################
# igw
###################

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}


###################
# eip + nat
###################

resource "aws_eip" "main_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}


resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.main_nat_eip.id
  subnet_id     = aws_subnet.public[0].id 

  tags = {
    Name = "main-nat"
  }

  depends_on = [aws_internet_gateway.main_igw]
}


#################################
# Subnets Public + Private
#################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count = 3

  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1) # 10.30.1.0/24, 10.30.2.0/24, 10.30.3.0/24
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = local.public_subnet_names[count.index]
  }
}

resource "aws_subnet" "private" {
  count = 3

  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 11) # 11,12,13
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-${count.index + 1}"
  }
}

#################################
# Route Tables
#################################

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "public-route"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_route.id
}

####Private####

resource "aws_route_table" "private_route" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id  = aws_nat_gateway.main_nat.id
  }

  tags = {
    Name = "private_route"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_route.id
}


#################################
# Security Groups (EC2 + RDS)
#################################

resource "aws_security_group" "ec2_lab_sg" {
  name        = "ec2-lab"
  description = "sg for http browser & ssh into"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "ec2-lab-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_lab_http" {
  security_group_id = aws_security_group.ec2_lab_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "ec2_lab_ssh" {
  security_group_id = aws_security_group.ec2_lab_sg.id
  cidr_ipv4         = "174.245.87.223/32" # var.my_ip_cidr # current 192.159.210.72/32 = east-1
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "ec2_lab_outbound" {
  security_group_id = aws_security_group.ec2_lab_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


#####RDS####

resource "aws_security_group" "rds_lab_sg" {
  name        = "rds-lab"
  description = "sg for rds private"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "rds-lab-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_lab_mysql" {
  security_group_id = aws_security_group.rds_lab_sg.id
  referenced_security_group_id = aws_security_group.ec2_lab_sg.id
  
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

resource "aws_vpc_security_group_egress_rule" "rds_mysql_outbound" {
  security_group_id = aws_security_group.rds_lab_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


#################################
# RDS Subnets Groups
#################################

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id


  tags = {
    Name = "rds-subnet-group"
  }
}


#################################
# RDS Instance
#################################

resource "aws_db_instance" "rds_lab_mysql" {
  identifier             = "lab-mysql"
  engine                 = var.db_engine
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_lab_sg.id]

  publicly_accessible    = false
  skip_final_snapshot    = true


  tags = {
    Name = "rds-lab-mysql"
  }
}


#################################
# EC2 Instance
#################################

resource "aws_instance" "ec2_lab" {
  ami                     = data.aws_ssm_parameter.al2023.value
  instance_type           = var.ec2_instance_type
  subnet_id               = aws_subnet.public[0].id
  vpc_security_group_ids  = [aws_security_group.ec2_lab_sg.id]
  iam_instance_profile    = aws_iam_instance_profile.iam_profile.name

     user_data = file("user_data.sh")

  tags = {
    Name = "ec2-lab"
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

#################################
# IAM Role + Instane Profile 
#################################

resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# resource "aws_iam_role_policy_attachment" "read_specific_secret" {
#   role      = aws_iam_role.ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
# }


data "aws_caller_identity" "current" {}
data "aws_region" "current_region" {}

resource "aws_iam_policy" "read_specific_secret" {
  name = "read-lab-rds-mysql"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadSpecificSecret"
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:${data.aws_region.current_region.region}:${data.aws_caller_identity.current.account_id}:secret:lab/rds/mysql*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_read_specific_secret" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.read_specific_secret.arn
}


# resource "aws_iam_role_policy_attachment" "cloud_watch_agent" {
#   role      = aws_iam_role.ec2_role.name
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
# }


resource "aws_iam_policy" "cloudwatch_agent_custom" {
  name        = "cloudwatch-agent-custom"
  description = "Permissions for CloudWatch Agent + SSM parameter reads for AmazonCloudWatch-*"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CWACloudWatchServerPermissions"
        Effect = "Allow"
        Action = [
          # "cloudwatch:PutMetricData",
          # "ec2:DescribeVolumes",
          # "ec2:DescribeTags",
          "logs:PutLogEvents",
          # "logs:PutRetentionPolicy",
          "logs:DescribeLogStreams",
          # "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          # "logs:CreateLogGroup",
          # "xray:PutTraceSegments",
          # "xray:PutTelemetryRecords",
          # "xray:GetSamplingRules",
          # "xray:GetSamplingTargets",
          # "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      },
      {
        Sid    = "CWASSMServerPermissions"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
      }
    ]
  })
}

# this will attach it to the role in the EC2
resource "aws_iam_role_policy_attachment" "attach_cloudwatch_agent_custom" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_custom.arn
}


# resource "aws_iam_role_policy_attachment" "ssm_manager_instance" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }


resource "aws_iam_policy" "ssm_managed_instance_core_custom" {
  name        = "ssm-managed-instance-core-custom"
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
resource "aws_iam_role_policy_attachment" "attach_ssm_core_custom" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ssm_managed_instance_core_custom.arn
}

# IAM policy allowing reads of just these 3 SSM parameters
resource "aws_iam_policy" "read_armageddon_db_params" {
  name        = "read-armageddon-db-params"
  description = "Allow ssm:GetParameters for lab-db endpoint/port/name parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadLabDbParams"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.armageddon_db_endpoint.arn,
          aws_ssm_parameter.armageddona_db_port.arn,
          aws_ssm_parameter.armageddon_db_name.arn
        ]
      }
    ]
  })
}

# this will attach it to the role in the EC2
resource "aws_iam_role_policy_attachment" "attach_read_armageddon_db_params" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.read_armageddon_db_params.arn
}


resource "aws_iam_instance_profile" "iam_profile" {
  name = "iam-profile"
  role = aws_iam_role.ec2_role.name
}


#################################
# Secret Manager
#################################

resource "aws_secretsmanager_secret" "lab_rds_mysql" {
  name = "lab/rds/mysql"
  recovery_window_in_days = 0

}

resource "aws_secretsmanager_secret_version" "lab_rds_mysql" {
  secret_id = aws_secretsmanager_secret.lab_rds_mysql.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.rds_lab_mysql.address
    port     = aws_db_instance.rds_lab_mysql.port
    dbname   = var.db_name
  })
}


###################################
# Parameter Store (SSM Parameters)
###################################

resource "aws_ssm_parameter" "armageddon_db_endpoint" {
  name  = "lab-db-endpoint"
  type  = "String"
  value = aws_db_instance.rds_lab_mysql.address

  tags = {
    Name = "param-db-endpoint"
  }
}

resource "aws_ssm_parameter" "armageddona_db_port" {
  name  = "lab-db-port"
  type  = "String"
  value = tostring(aws_db_instance.rds_lab_mysql.port)

  tags = {
    Name = "param-db-port"
  }
}

resource "aws_ssm_parameter" "armageddon_db_name" {
  name  = "lab-db-name"
  type  = "String"
  value = var.db_name

  tags = {
    Name = "param-db-name"
  }
}


###################################
# CloudWatch Logs (Log Watch)
###################################

resource "aws_cloudwatch_log_group" "rds_log_group" {
  name   = "rds-app"
  retention_in_days = 7

  tags = {
    Name = "rds-log-group"
  }
}

resource "aws_cloudwatch_log_metric_filter" "rds_connection_error" {
  name           = "rds-connection-error"
  pattern = "OperationalError"
  log_group_name = aws_cloudwatch_log_group.rds_log_group.name

  metric_transformation {
    name      = "DBConnectionErrors"
    namespace = "Lab/RDSApp"
    value     = "1"
  }
}


###################################
# Custom Metric + Alarm
###################################

resource "aws_cloudwatch_metric_alarm" "alarm_db_fail" {
  alarm_name          = "alarm-db-fail"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1

  metric_name = "DBConnectionErrors"
  namespace   = "Lab/RDSApp"
  period      = 60
  statistic   = "Sum"
  threshold   = 3

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.lab_db_incidents.arn]

  tags = { Name = "alarm-db-fail" }
}


##############
# SNS
##############

resource "aws_sns_topic" "lab_db_incidents" {
  name = "db-incidents"
}

resource "aws_sns_topic_subscription" "db_incidents" {
  topic_arn = aws_sns_topic.lab_db_incidents.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}








