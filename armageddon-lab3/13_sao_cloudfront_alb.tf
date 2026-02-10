# data "aws_acm_certificate" "sao_cf" {
#   provider    = aws.use1
#   domain      = var.domain_name
#   statuses    = ["ISSUED"]
#   most_recent = true
# }

# locals {
#   sao_cf_cert_arn = data.aws_acm_certificate.sao_cf.arn
# }


# resource "aws_cloudfront_distribution" "sao_armageddon_cf_dis" {
#     provider = aws.use1
#   enabled         = true
#   is_ipv6_enabled = true
#   comment         = "${var.project_name}-sao-cf01-dis"

#   origin {
#     origin_id   = "${var.project_name}-sao-alb-origin01"
#     domain_name = "origin.${var.domain_name}"

#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "https-only"
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }

    
#     custom_header {
#       name  = "King-Iron-Fist"
#       value = random_password.sao_armageddon_origin_header_value01.result
#     }
#   }

# default_cache_behavior {
#   target_origin_id       = "${var.project_name}-sao-alb-origin01"
#   viewer_protocol_policy = "redirect-to-https"

#   allowed_methods = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
#   cached_methods  = ["GET","HEAD"]

#   cache_policy_id          = data.aws_cloudfront_cache_policy.sao_armageddon_caching_disabled01.id
#   origin_request_policy_id = data.aws_cloudfront_origin_request_policy.sao_armageddon_orp_all_viewer_except_host01.id
# }


# # Public feed cache
# ordered_cache_behavior {
#   path_pattern           = "/api/public-feed"
#   target_origin_id       = "${var.project_name}-sao-alb-origin01"
#   viewer_protocol_policy = "redirect-to-https"

#   allowed_methods = ["GET", "HEAD", "OPTIONS"]
#   cached_methods  = ["GET", "HEAD"]

#   cache_policy_id = data.aws_cloudfront_cache_policy.sao_armageddon_use_origin_cache_headers01.id
#   origin_request_policy_id = aws_cloudfront_origin_request_policy.sao_armageddon_orp_static01.id
# }


# # Cache-Control from origin
# ordered_cache_behavior {
#   path_pattern           = "/api/*"
#   target_origin_id       = "${var.project_name}-sao-alb-origin01"
#   viewer_protocol_policy = "redirect-to-https"

#   allowed_methods = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
#   cached_methods  = ["GET","HEAD"]

#   cache_policy_id          = data.aws_cloudfront_cache_policy.sao_armageddon_caching_disabled01.id
#   origin_request_policy_id = data.aws_cloudfront_origin_request_policy.sao_armageddon_orp_all_viewer_except_host01.id

  
# }

# ordered_cache_behavior {
#   path_pattern           = "/static/*"
#   target_origin_id       = "${var.project_name}-sao-alb-origin01"
#   viewer_protocol_policy = "redirect-to-https"

#   allowed_methods = ["GET","HEAD","OPTIONS"]
#   cached_methods  = ["GET","HEAD"]

#   cache_policy_id            = aws_cloudfront_cache_policy.sao_armageddon_cache_static01.id
#   origin_request_policy_id   = aws_cloudfront_origin_request_policy.sao_armageddon_orp_static01.id
#   response_headers_policy_id = aws_cloudfront_response_headers_policy.sao_armageddon_rsp_static01.id
# }


#   web_acl_id = aws_wafv2_web_acl.sao_armageddon_cf_waf.arn

  
#   aliases = [
#     var.domain_name,
#     "${var.app_subdomain}.${var.domain_name}"
#   ]

  
#   viewer_certificate {
#     acm_certificate_arn = local.sao_cf_cert_arn
#     ssl_support_method       = "sni-only"
#     minimum_protocol_version = "TLSv1.2_2021"
#   }

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
# }


# ################################
# # data_cache_policy 
# ################################

# data "aws_cloudfront_cache_policy" "sao_armageddon_use_origin_cache_headers01" {
#   name = "UseOriginCacheControlHeaders"
# }

# data "aws_cloudfront_cache_policy" "sao_armageddon_use_origin_cache_headers_qs01" {
#   name = "UseOriginCacheControlHeaders-QueryStrings"
# }

# data "aws_cloudfront_origin_request_policy" "sao_armageddon_orp_all_viewer01" {
#   name = "Managed-AllViewer"
# }

# data "aws_cloudfront_origin_request_policy" "sao_armageddon_orp_all_viewer_except_host01" {
#   name = "Managed-AllViewerExceptHostHeader"
# }

# data "aws_cloudfront_cache_policy" "sao_armageddon_caching_disabled01" {
#   name = "Managed-CachingDisabled"
# }



