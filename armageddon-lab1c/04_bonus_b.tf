#######################
# Bonus B
#######################


###########################
# Security Group: ALB
###########################

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "ALB security group"
  vpc_id              = aws_vpc.main_vpc.id

  tags = {
    Name = "alb-sg"
  }
}

#HTTP 80 for alb
resource "aws_security_group_rule" "alb_ingress_http" {
  type                     = "ingress"
  security_group_id        = aws_security_group.alb_sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

#HTTPS 443 for alb
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress_to_ec2_http" {
  type                     = "egress"
  security_group_id        = aws_security_group.alb_sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpcend_sg.id
}

# this allows ALB to reach the private EC2 instance
resource "aws_security_group_rule" "ec2_ingress_from_alb_http" {
  type                     = "ingress"
  security_group_id        = aws_security_group.vpcend_sg.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
}


###################################
# Application Load Balancer
###################################

resource "aws_lb" "armageddon_alb" {
  name               = "armageddon-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.alb_sg.id]
  subnets = slice(aws_subnet.public[*].id, 0, 2) # takes only the first two subnet IDs from aws_subnet.public list and uses those for the resource

  access_logs {
    bucket  = aws_s3_bucket.armageddon_alb_logs_bucket[0].bucket
    prefix  = var.alb_access_logs_prefix
    enabled = var.enable_alb_access_logs
  }

  tags = {
    Name = "armageddon-alb"
  }
}

###################################
# Target Group + Attachment
###################################

resource "aws_lb_target_group" "armageddon_tg" {
  name     = "armageddon-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

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
    Name = "armageddon-tg"
  }
}


resource "aws_lb_target_group_attachment" "armageddon_tg_attach" {
  target_group_arn = aws_lb_target_group.armageddon_tg.arn
  target_id        = aws_instance.ec2_private_b.id
  port             = 80
}

############################################
# ACM Certificate (TLS) for librashift.com
############################################

resource "aws_acm_certificate" "armageddon_acm_cert01" {
  count             = var.create_certificate ? 1 : 0
  domain_name       = var.domain_name
  validation_method = var.certificate_validation_method

  tags = {
    Name = "acm-cert01"
  }
}

resource "aws_acm_certificate_validation" "armageddon_acm_validation01" {
  count = var.certificate_validation_method == "DNS" ? 1 : 0

  certificate_arn = aws_acm_certificate.armageddon_acm_cert01[0].arn
  validation_record_fqdns = [for r in aws_route53_record.armageddon_record : r.fqdn]
}

############################################
# ALB Listeners: HTTP -> HTTPS redirect, HTTPS -> TG
############################################

resource "aws_lb_listener" "armageddon_http_listener" {
  load_balancer_arn = aws_lb.armageddon_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "armageddon_https_listener" {
  load_balancer_arn = aws_lb.armageddon_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.armageddon_tg.arn
  }

  depends_on = [aws_acm_certificate_validation.armageddon_acm_validation01]
}

############################################
# WAFv2 Web ACL (Basic managed rules)
############################################

resource "aws_wafv2_web_acl" "armageddon_waf" {
  count = var.enable_waf ? 1 : 0

  name  = "armageddon-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "armageddon-waf"
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
      metric_name                = "waf-common"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "armageddon-waf"
  }
}

resource "aws_wafv2_web_acl_association" "armageddon_waf_assoc01" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_lb.armageddon_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.armageddon_waf[0].arn
}

############################################
# CloudWatch Alarm: ALB 5xx -> SNS
############################################

resource "aws_cloudwatch_metric_alarm" "armage_alb_5xx_alarm01" {
  alarm_name          = "armage-alb-5xx-alarm01"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alb_5xx_evaluation_periods
  threshold           = var.alb_5xx_threshold
  period              = var.alb_5xx_period_seconds
  statistic           = "Sum"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.armageddon_alb.arn_suffix
  }

  alarm_actions = [aws_sns_topic.lab_db_incidents.arn]

  tags = {
    Name = "armage-alb-5xx-alarm01"
  }
}

############################################
# CloudWatch Dashboard (Skeleton)
############################################

resource "aws_cloudwatch_dashboard" "armageddon_dashboard" {
  dashboard_name = "armageddon-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type  = "metric"
        x     = 0
        y     = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.armageddon_alb.arn_suffix ],
            [ ".", "HTTPCode_ELB_5XX_Count", ".", aws_lb.armageddon_alb.arn_suffix ]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Armageddon ALB: Requests + 5XX"
        }
      },
      {
        type  = "metric"
        x     = 12
        y     = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.armageddon_alb.arn_suffix ]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Armageddon ALB: Target Response Time"
        }
      }
    ]
  })
}
