# resource "aws_cloudfront_create_invalidation" "armageddon_invalidate_index01" {
#   distribution_id = aws_cloudfront_distribution.armageddon_cf01.id


#   paths = [
#     "/static/index.html"
#   ]
# }