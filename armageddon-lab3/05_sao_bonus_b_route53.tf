#######################
# Bonus C
#######################

###########################
# Route 53
###########################

locals {
  armageddon_sao_zone_name = var.domain_name
  
  sao_armageddon_zone_id = var.route53_hosted_zone_id
}


data "aws_acm_certificate" "sao_existing" {
  provider = aws.saopaulo
  count       = var.create_certificate ? 0 : 1
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  sao_created_cert_arn  = try(aws_acm_certificate_validation.sao_armageddon_acm_validation01[0].certificate_arn, null)
  sao_existing_cert_arn = try(data.aws_acm_certificate.sao_existing[0].arn, null)

  sao_certificate_arn = coalesce(local.sao_created_cert_arn, local.sao_existing_cert_arn)
}

# resource "aws_route53_zone" "sao_armageddon_zone01" {
#   count = var.manage_route53_in_terraform ? 1 : 0
#   name  = local.armageddon_sao_zone_name

#   tags = {
#     Name = "sao-armageddon-zone01"
#   }
# }

resource "aws_route53_record" "sao_armageddon_record" {
  for_each = var.create_certificate ? {
    for dvo in aws_acm_certificate.sao_armageddon_acm_cert01[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  allow_overwrite = true # so it doesn't duplicate CNAME when creating

  zone_id = local.sao_armageddon_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

