output "sns_topic_arn" {
  value = aws_sns_topic.lab_db_incidents.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.rds_log_group.name
}

#######################
# Bonus-A_Outputs
#######################

output "ec2pri_ssm_id" {
  value = aws_vpc_endpoint.ec2pri_ssm.id
}

output "ec2pri_logs_id" {
  value = aws_vpc_endpoint.ec2pri_logs.id
}

output "ec2pri_secrets_id" {
  value = aws_vpc_endpoint.ec2pri_secrets.id
}

output "ec2pri_s3_id" {
  value = aws_vpc_endpoint.ec2pri_s3_gw.id
}

output "private_ec2_instance_id_bonus" {
  value = aws_instance.ec2_private_b.id
}

#######################
# Bonus-B_Outputs
#######################

output "alb_dns_name" {
  value = aws_lb.armageddon_alb.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.armageddon_tg.arn
}

output "acm_cert_arn" {
  value = aws_acm_certificate.armageddon_acm_cert01[0].arn
}

output "waf_arn" {
  value = var.enable_waf ? aws_wafv2_web_acl.armageddon_waf[0].arn : null
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.armageddon_dashboard.dashboard_name
}

output "acm_dns_validation_records_to_send" {
  value = {
    for dvo in aws_acm_certificate.armageddon_acm_cert01[0].domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

#######################
# Bonus-C_Outputs
#######################

output "route53_zone_id" {
  value = local.armageddon_zone_id
}

output "hosted_zone_name_servers" {
  value = var.manage_route53_in_terraform ? aws_route53_zone.armageddon_zone01[0].name_servers : null
}

#######################
# Bonus-D_Outputs
#######################

output "apex_url_https" {
  value = "https://${var.domain_name}"
}

output "alb_logs_bucket_name" {
  value = var.enable_alb_access_logs ? aws_s3_bucket.armageddon_alb_logs_bucket[0].bucket : null
}

#######################
# Bonus-E_Outputs
#######################

output "armageddon_waf_log_destination" {
  value = var.waf_log_destination
}

output "armageddon_waf_firehose_name" {
  value = var.waf_log_destination == "firehose" ? aws_kinesis_firehose_delivery_stream.armageddon_waf_firehose01[0].name : null
}