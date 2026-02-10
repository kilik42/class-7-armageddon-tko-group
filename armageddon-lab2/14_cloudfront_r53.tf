
resource "aws_route53_record" "armageddon_apex_to_cf01" {
  zone_id = local.armageddon_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.armageddon_cf_dis.domain_name
    zone_id                = aws_cloudfront_distribution.armageddon_cf_dis.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "armageddon_app_to_cf01" {
  zone_id = local.armageddon_zone_id
  name    = var.app_subdomain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.armageddon_cf_dis.domain_name
    zone_id                = aws_cloudfront_distribution.armageddon_cf_dis.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "armageddon_origin_to_alb01" {
  zone_id = local.armageddon_zone_id
  name    = "origin.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.armageddon_alb.dns_name
    zone_id                = aws_lb.armageddon_alb.zone_id
    evaluate_target_health = false
  }
}
