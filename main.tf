terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "my-bucket" {
  bucket = "ved-int-test11"

  tags = {
    Name = "My bucket"
  }
}

locals {
  s3_origin_id = "vedtestcdn"
}


resource "aws_s3_bucket_policy" "allow_access"{
    bucket = aws_s3_bucket.my-bucket.id
    policy = data.aws_iam_policy_document.allow_access.json
}

data "aws_iam_policy_document" "allow_access" {
    statement {
        actions = [ "s3:*" ]
        resources = [ "${aws_s3_bucket.my-bucket.arn}", "${aws_s3_bucket.my-bucket.arn}/*"  ]
        principals {
           type = "Service"
           identifiers = ["cloudfront.amazonaws.com"]
        }
       condition {
         test = "StringEquals"
         variable = "AWS:SourceArn"
         values = ["${aws_cloudfront_distribution.s3_distribution.arn}"]
       }
    }
}

resource "aws_cloudfront_origin_access_identity" "my_origin_access_identity" {
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.my-bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.my_origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  default_cache_behavior {
    cache_policy_id  = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    viewer_protocol_policy = "allow-all"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

}



