resource "aws_iam_user" "s3_user" {
  name = "${local.s3_bucket_name}-user-${random_id.suffix.hex}"
  tags = {
    Name = "S3 User"
  }
}

resource "aws_iam_access_key" "s3_user_access_key" {
  user = aws_iam_user.s3_user.name
}

resource "random_id" "suffix" {
  byte_length = 8 # Adjust length as needed
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  force_destroy = true

  bucket = local.s3_bucket_name
  acl    = "private"

  attach_require_latest_tls_policy         = true
  attach_deny_incorrect_encryption_headers = true

  cors_rule = [
    {
      allowed_methods = ["PUT", "POST"]
      allowed_origins = ["https://api.${var.zone_name}", "https://${var.zone_name}"]
      allowed_headers = ["*"]
      expose_headers = ["ETag"]
      max_age_seconds = 3000
    },
  ]
}

resource "aws_iam_user_policy" "s3_policy" {
  name = "s3-access-policy"  # Name of the IAM policy
  user = aws_iam_user.s3_user.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:ListBucket",
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::${local.s3_bucket_name}"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::${local.s3_bucket_name}/*"
      },
    ]
  })
}

locals {
  s3_bucket_name       = "${local.name}-${var.environment}-web"
  s3_access_key_id     = aws_iam_access_key.s3_user_access_key.id
  s3_secret_access_key = aws_iam_access_key.s3_user_access_key.secret
}