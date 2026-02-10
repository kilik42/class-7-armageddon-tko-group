
# data "aws_ec2_managed_prefix_list" "sao_armageddon_cf_origin_facing01" {
#   provider = aws.saopaulo
#   name = "com.amazonaws.global.cloudfront.origin-facing"
# }

# resource "random_password" "sao_armageddon_origin_header_value01" {
#   length  = 32
#   special = false
# }

# resource "aws_lb_listener_rule" "sao_armageddon_require_origin_header" {
#   provider = aws.saopaulo
#   listener_arn = aws_lb_listener.sao_armageddon_https_listener.arn
#   priority     = 10

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.sao_armageddon_tg.arn
#   }

#   condition {
#     http_header {
#       http_header_name = "King-Iron-Fist"
#       values           = [random_password.sao_armageddon_origin_header_value01.result]
#     }
#   }
# }

# resource "aws_lb_listener_rule" "sao_armageedon_default_block" {
#     provider = aws.saopaulo
#   listener_arn = aws_lb_listener.sao_armageddon_https_listener.arn
#   priority     = 99

#   action {
#     type = "fixed-response"
#     fixed_response {
#       content_type = "text/plain"
#       message_body = "Forbidden"
#       status_code  = "403"
#     }
#   }

#   condition {
#     path_pattern { values = ["/*"] }
#   }
# }