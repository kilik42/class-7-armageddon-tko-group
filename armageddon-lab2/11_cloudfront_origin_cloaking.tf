
data "aws_ec2_managed_prefix_list" "armageddon_cf_origin_facing01" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "random_password" "armageddon_origin_header_value01" {
  length  = 32
  special = false
}

resource "aws_lb_listener_rule" "armageddon_require_origin_header" {
  listener_arn = aws_lb_listener.armageddon_https_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.armageddon_tg.arn
  }

  condition {
    http_header {
      http_header_name = "King-Iron-Fist"
      values           = [random_password.armageddon_origin_header_value01.result]
    }
  }
}

resource "aws_lb_listener_rule" "armageedon_default_block" {
  listener_arn = aws_lb_listener.armageddon_https_listener.arn
  priority     = 99

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }

  condition {
    path_pattern { values = ["/*"] }
  }
}