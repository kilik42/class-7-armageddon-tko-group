
# resource "aws_route53_record" "sao_armageddon_apex_to_cf01" {
#   zone_id = local.sao_armageddon_zone_id
#   name    = var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.sao_armageddon_cf_dis.domain_name
#     zone_id                = aws_cloudfront_distribution.sao_armageddon_cf_dis.hosted_zone_id
#     evaluate_target_health = false
#   }
# }

# resource "aws_route53_record" "sao_armageddon_app_to_cf01" {
#   zone_id = local.sao_armageddon_zone_id
#   name    = "${var.app_subdomain}.${var.domain_name}"
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.sao_armageddon_cf_dis.domain_name
#     zone_id                = aws_cloudfront_distribution.sao_armageddon_cf_dis.hosted_zone_id
#     evaluate_target_health = false
#   }
# }

resource "aws_route53_record" "origin_sao_to_alb" {
  zone_id = local.sao_armageddon_zone_id   # hosted zone for librashift.com
  name    = "origin-sao.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.sao_armageddon_alb.dns_name
    zone_id                = aws_lb.sao_armageddon_alb.zone_id
    evaluate_target_health = true
  }
}


