#######################
# Bonus B
#######################


###########################
# Security Group: ALB
###########################

resource "aws_security_group" "sao_alb_sg" {
    provider = aws.saopaulo
  name        = "alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.sao_main_vpc.id

  tags = {
    Name = "sao-alb-sg"
  }
}

#HTTP 443 for alb

resource "aws_security_group_rule" "sao_alb_ingress_https_public" {
  provider          = aws.saopaulo
  type              = "ingress"
  security_group_id = aws_security_group.sao_alb_sg.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# resource "aws_security_group_rule" "sao_alb_ingress_http_cf" {
#     provider = aws.saopaulo
#   type = "ingress"
#   security_group_id = aws_security_group.sao_alb_sg.id
#   from_port         = 443
#   to_port           = 443
#   protocol          = "tcp"
#   prefix_list_ids   = [data.aws_ec2_managed_prefix_list.sao_armageddon_cf_origin_facing01.id]
# }


resource "aws_security_group_rule" "sao_alb_to_ec2_http" {
    provider = aws.saopaulo
  type              = "egress"
  security_group_id = aws_security_group.sao_alb_sg.id

  protocol  = "tcp"
  from_port = 80
  to_port   = 80

  # destination = the EC2 private SG
  source_security_group_id = aws_security_group.sao_ec2pri_sg.id
}


resource "aws_security_group_rule" "sao_ec2_all_out" {
    provider = aws.saopaulo
  type              = "egress"
  security_group_id = aws_security_group.sao_ec2pri_sg.id

  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]
}


# this allows ALB to reach the private EC2 instance
resource "aws_security_group_rule" "sao_ec2_ingress_from_alb_http" {
    provider = aws.saopaulo
  type                     = "ingress"
  security_group_id        = aws_security_group.sao_ec2pri_sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sao_alb_sg.id
}


###################################
# Application Load Balancer
###################################

resource "aws_lb" "sao_armageddon_alb" {
    provider = aws.saopaulo
  name               = "sao-armageddon-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.sao_alb_sg.id]
  subnets         = slice(aws_subnet.sao_public[*].id, 0, 2) # takes only the first two subnet IDs from aws_subnet.public list and uses those for the resource

 dynamic "access_logs" {
  for_each = var.enable_alb_access_logs ? [1] : []
  content {
    bucket  = aws_s3_bucket.sao_armageddon_alb_logs_bucket[0].bucket
    prefix  = var.alb_access_logs_prefix
    enabled = var.enable_alb_access_logs
  }
 }
  tags = {
    Name = "sao-armageddon-alb"
  }
}

###################################
# Target Group + Attachment
###################################

resource "aws_lb_target_group" "sao_armageddon_tg" {
    provider = aws.saopaulo
  name     = "sao-armageddon-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sao_main_vpc.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "sao-armageddon-tg"
  }
}


# resource "aws_lb_target_group_attachment" "sao_armageddon_tg_attach" {
#     provider = aws.saopaulo
#   target_group_arn = aws_lb_target_group.sao_armageddon_tg.arn
#   target_id        = aws_instance.sao_ec2_private_b.id
#   port             = 80
# }

###################################
# Launch Template
###################################

data "aws_ssm_parameter" "sao_al2023" {
  provider = aws.saopaulo
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "sao_armageddon_web" {
  provider    = aws.saopaulo
  name_prefix = "sao-armageddon-web"
  description = "launch template for web tier servers"

  image_id      = data.aws_ssm_parameter.sao_al2023.value
  instance_type = var.ec2_instance_type

  vpc_security_group_ids = [aws_security_group.sao_ec2pri_sg.id]

  user_data = filebase64("${path.module}/user_dataprivate.sh")

  # Tags on the launch template object itself
  tags = {
    Name = "sao-armageddon-web"
  }

  # Tags that propagate to EC2 instances + EBS volumes created from this LT
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "sao-web"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "sao-web"
    }
  }

  # Good security default
  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }
iam_instance_profile {
  name = aws_iam_instance_profile.sao_iam_profile.name
  }
}

###################################
# ASG
###################################

resource "aws_autoscaling_group" "sao_asg" {
    provider = aws.saopaulo
    name = "sao-asg"
    vpc_zone_identifier = aws_subnet.sao_private[*].id
    max_size            = 3 
    min_size            = 1 
    desired_capacity = 2 
    health_check_type = "ELB"
    health_check_grace_period = 120
    target_group_arns = [aws_lb_target_group.sao_armageddon_tg.arn]
    force_delete = true
    
     launch_template {
    id      = aws_launch_template.sao_armageddon_web.id
    version = "$Latest"
  }

 tag {
    key = "name"
    value ="web-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "sao_policy" {
    provider = aws.saopaulo
  name                   = "sao-policy"
  autoscaling_group_name = aws_autoscaling_group.sao_asg.name

  policy_type = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}


############################################
# ACM Certificate (TLS) for librashift.com
############################################

resource "aws_acm_certificate" "sao_armageddon_acm_cert01" {
    provider = aws.saopaulo
  count                     = var.create_certificate ? 1 : 0
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = var.certificate_validation_method



  tags = {
    Name = "sao-acm-cert01"
  }
}

resource "aws_acm_certificate_validation" "sao_armageddon_acm_validation01" {
  provider = aws.saopaulo
  count    = (var.create_certificate && var.certificate_validation_method == "DNS") ? 1 : 0

  certificate_arn         = aws_acm_certificate.sao_armageddon_acm_cert01[0].arn
  validation_record_fqdns = [for r in aws_route53_record.sao_armageddon_record : r.fqdn]
}


############################################
# ALB Listeners: HTTP -> HTTPS redirect, HTTPS -> TG
############################################

# resource "aws_lb_listener" "sao_armageddon_http_listener" {
#     provider = aws.saopaulo
#   load_balancer_arn = aws_lb.sao_armageddon_alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

resource "aws_lb_listener" "sao_armageddon_https_listener" {
    provider = aws.saopaulo
  load_balancer_arn = aws_lb.sao_armageddon_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.sao_certificate_arn


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sao_armageddon_tg.arn
  }

  depends_on = [aws_acm_certificate_validation.sao_armageddon_acm_validation01]
}

############################################
# WAFv2 Web ACL (Basic managed rules)
############################################

resource "aws_wafv2_web_acl" "sao_armageddon_waf" {
    provider = aws.saopaulo
  count = var.enable_waf ? 1 : 0

  name  = "sao-armageddon-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "sao-armageddon-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sao-waf-common"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "sao-armageddon-waf"
  }
}

resource "aws_wafv2_web_acl_association" "sao_armageddon_waf_assoc01" {
  count = var.enable_waf ? 1 : 0
  provider = aws.saopaulo

  resource_arn = aws_lb.sao_armageddon_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.sao_armageddon_waf[0].arn
}

############################################
# CloudWatch Alarm: ALB 5xx -> SNS
############################################

resource "aws_sns_topic" "incidents_sao" {
  provider = aws.saopaulo
  name     = "incidents-sao"
}

resource "aws_cloudwatch_metric_alarm" "sao_armage_alb_5xx_alarm01" {
    provider = aws.saopaulo
  alarm_name          = "sao-armage-alb-5xx-alarm01"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alb_5xx_evaluation_periods
  threshold           = var.alb_5xx_threshold
  period              = var.alb_5xx_period_seconds
  statistic           = "Sum"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.sao_armageddon_alb.arn_suffix
  }

  alarm_actions = [aws_sns_topic.incidents_sao.arn]

  tags = {
    Name = "armage-alb-5xx-alarm01"
  }
}

############################################
# CloudWatch Dashboard 
############################################

resource "aws_cloudwatch_dashboard" "sao_armageddon_dashboard" {
    provider = aws.saopaulo
  dashboard_name = "sao-armageddon-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.sao_armageddon_alb.arn_suffix],
            [".", "HTTPCode_ELB_5XX_Count", ".", aws_lb.sao_armageddon_alb.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = "sa-east-1"
          title  = "Armageddon ALB: Requests + 5XX"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.sao_armageddon_alb.arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = "sa-east-1"
          title  = "Armageddon ALB: Target Response Time"
        }
      }
    ]
  })
}
