terraform {
  backend "s3" {
    bucket         = "<bucket in backend>"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "<Dynamo db table for locking>"
    encrypt        = true
  }

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
  bucket = "<unique name for bucket>"

  tags = {
    Name = "My bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "ownership_controls" {
    bucket = aws_s3_bucket.my-bucket.id
    rule {
        object_ownership = "BucketOwnerPreferred"
    }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.ownership_controls]

  bucket = aws_s3_bucket.my-bucket.id
  acl    = "private"
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
        principals {
           type = "Service"
           identifiers = ["cloudfront.amazonaws.com"]
        }
       actions = [ "s3:*" ]
       resources = [ "${aws_s3_bucket.my-bucket.arn}", "${aws_s3_bucket.my-bucket.arn}/*"  ]
       condition {
         test = "StringEquals"
         variable = "AWS:SourceArn"
         values = ["${aws_cloudfront_distribution.s3_distribution.arn}"]
       }
    }
}

resource "aws_cloudfront_origin_access_control" "example" {
  name                              = "example"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.my-bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.example.id
    origin_id   = local.s3_origin_id

  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
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


output "distribution_id" {
    value = "${aws_cloudfront_distribution.s3_distribution.id}"
}

