#######################
# Bonus E
#######################

resource "aws_s3_bucket" "armageddon_firehose_waf_dest_bucket01" {
  count = var.waf_log_destination == "firehose" ? 1 : 0

  bucket = "${var.project_name}-waf-firehose-dest-${data.aws_caller_identity.armageddon_self.account_id}"

  tags = {
    Name = "${var.project_name}-waf-firehose-dest-bucket01"
  }
}

resource "aws_iam_role" "armageddon_firehose_role01" {
  count = var.waf_log_destination == "firehose" ? 1 : 0
  name  = "${var.project_name}-firehose-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "armageddon_firehose_policy01" {
  count = var.waf_log_destination == "firehose" ? 1 : 0
  name  = "${var.project_name}-firehose-policy01"
  role  = aws_iam_role.armageddon_firehose_role01[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.armageddon_firehose_waf_dest_bucket01[0].arn,
          "${aws_s3_bucket.armageddon_firehose_waf_dest_bucket01[0].arn}/*"
        ]
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "armageddon_waf_firehose01" {
  count       = var.waf_log_destination == "firehose" ? 1 : 0
  name        = "aws-waf-logs-${var.project_name}-firehose01"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.armageddon_firehose_role01[0].arn
    bucket_arn = aws_s3_bucket.armageddon_firehose_waf_dest_bucket01[0].arn
    prefix     = "waf-logs/"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "armageddon_waf_logging_firehose01" {
  count = var.enable_waf && var.waf_log_destination == "firehose" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.armageddon_waf[0].arn
  log_destination_configs = [
    aws_kinesis_firehose_delivery_stream.armageddon_waf_firehose01[0].arn
  ]

  depends_on = [aws_wafv2_web_acl.armageddon_waf]
}