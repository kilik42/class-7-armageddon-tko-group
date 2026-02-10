#######################
# Bonus E
#######################

resource "aws_s3_bucket" "armageddon_firehose_waf_dest_bucket_tokyo01" {
  provider      = aws
  count         = var.waf_log_destination == "firehose" ? 1 : 0
  force_destroy = true

  # must be a NEW unique bucket name (bucket names are global)
  bucket = "${var.project_name}-waf-firehose-dest-apne1-${data.aws_caller_identity.armageddon_self.account_id}"
}

resource "aws_iam_role" "armageddon_firehose_role_tokyo01" {
  provider = aws
  count    = var.waf_log_destination == "firehose" ? 1 : 0
  name     = "${var.project_name}-firehose-role-apne1"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "armageddon_firehose_policy_tokyo01" {
  provider = aws
  count    = var.waf_log_destination == "firehose" ? 1 : 0
  name     = "${var.project_name}-firehose-policy-apne1"
  role     = aws_iam_role.armageddon_firehose_role_tokyo01[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
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
        aws_s3_bucket.armageddon_firehose_waf_dest_bucket_tokyo01[0].arn,
        "${aws_s3_bucket.armageddon_firehose_waf_dest_bucket_tokyo01[0].arn}/*"
      ]
    }]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "armageddon_waf_firehose_tokyo01" {
  provider    = aws
  count       = var.waf_log_destination == "firehose" ? 1 : 0
  name        = "aws-waf-logs-${var.project_name}-apne1-firehose01"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.armageddon_firehose_role_tokyo01[0].arn
    bucket_arn = aws_s3_bucket.armageddon_firehose_waf_dest_bucket_tokyo01[0].arn
    prefix     = "waf-logs/"
  }
}

