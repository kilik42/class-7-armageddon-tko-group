#######################
# Bonus D
#######################

data "aws_caller_identity" "armageddon_self" {}

resource "aws_s3_bucket" "armageddon_alb_logs_bucket" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = "armageddon-alb-logs-${data.aws_caller_identity.armageddon_self.account_id}"

  tags = {
    Name = "armageddon-alb-logs-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "armageddon_alb_logs_pab" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.armageddon_alb_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "armageddon_alb_logs_owner" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.armageddon_alb_logs_bucket[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_policy" "armageddon_alb_logs_policy" {
  count  = var.enable_alb_access_logs ? 1 : 0
  bucket = aws_s3_bucket.armageddon_alb_logs_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.armageddon_alb_logs_bucket[0].arn,
          "${aws_s3_bucket.armageddon_alb_logs_bucket[0].arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid    = "AllowALBLogDelivery"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = (
          var.alb_access_logs_prefix != ""
          ? "${aws_s3_bucket.armageddon_alb_logs_bucket[0].arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.armageddon_self.account_id}/*"
          : "${aws_s3_bucket.armageddon_alb_logs_bucket[0].arn}/AWSLogs/${data.aws_caller_identity.armageddon_self.account_id}/*"
        )
      }
    ]
  })
}
