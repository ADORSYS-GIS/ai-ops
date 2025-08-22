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

  force_destroy     = true
  block_public_acls = true

  bucket = local.s3_bucket_name

  attach_policy = true

  cors_rule = [
    {
      allowed_methods = ["PUT", "POST"]
      allowed_origins = ["https://${var.zone_name}"]
      allowed_headers = ["*"]
      expose_headers = ["ETag"]
      max_age_seconds = 3000
    },
  ]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_user.s3_user.arn
        },
        Action = [
          "s3:*",
        ],
        Resource = [
          "arn:aws:s3:::${local.s3_bucket_name}",
          "arn:aws:s3:::${local.s3_bucket_name}/*"
        ]
      }
    ]
  })
  
  tags = local.tags
}

locals {
  s3_bucket_name       = "${local.name}-${var.environment}-web"
  s3_access_key_id     = aws_iam_access_key.s3_user_access_key.id
  s3_secret_access_key = aws_iam_access_key.s3_user_access_key.secret
}