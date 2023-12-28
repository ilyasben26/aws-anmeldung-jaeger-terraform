provider "aws" {
  region = "eu-central-1"
}

# S3 Buckets

resource "aws_s3_bucket" "aj_bucket" {
  bucket = "aj-bucket-lambda-outputs"

  tags = {
    Name = "AJ Lambda Outputs"
  }
}


# Lambda

resource "aws_iam_role" "lambda_role" {
  name = "aj_lambda_role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
          "Effect" : "Allow",
          "Sid" : ""
        }
      ]
    }
  )
}
