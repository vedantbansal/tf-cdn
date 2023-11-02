# CloudFront with Terraform

## For Backend
- To store the state file, create a S3 bucket
- Block all public access
- enable bucket versioning
- enable default encryption
- change bucket policy as explained further
- create a DynamoDB table to lock the state files
- Name partition key as: "LockID" (it needs to be exact this name)


## Policy for backend S3 bucket 
```
{
    "Version": "2012-10-17",
    "Id": "Policy1680820022117",
    "Statement": [
        {
            "Sid": "Stmt1680819929502",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::<account>:user/USER"
            },
            "Action": [
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::S3-BUCKET-NAME",
                "arn:aws:s3:::S3-BUCKET-NAME/global/s3/terraform.tfstate"
            ]
        },
        {
            "Sid": "Stmt1680819959950",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:DeleteBucket",
            "Resource": "arn:aws:s3:::S3-BUCKET-NAME"
        }
    ]
}
```

## Allow cloudfront to access S3 bucket by adding following code

```
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
```

## Add origin access control

```
resource "aws_cloudfront_origin_access_control" "example" {
  name                              = "example"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

### Insert this in origin 

```
origin_access_control_id = aws_cloudfront_origin_access_control.example.id
```

