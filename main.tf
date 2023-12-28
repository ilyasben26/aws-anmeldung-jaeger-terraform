provider "aws" {
  region = "eu-central-1"
}

resource "aws_iam_role" "lambda_role" {
  name               = "aj_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM policy for logging lambda
# TODO: create new S3 bucket for data.json and change the resource in the role
# TODO: the same for DDB
resource "aws_iam_policy" "iam_policy_for_lambda" {

  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LoggingCloudWatch",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
        "Sid": "S3PutData",
		"Effect": "Allow",
		"Action": "s3:PutObject",
		"Resource": "arn:aws:s3:::anmeldung-jaeger.com/data.json" 
	},
    {
		"Sid": "DDBGetPutCache",
		"Effect": "Allow",
		"Action": [
			"dynamodb:GetItem",
			"dynamodb:PutItem"
		],
		"Resource": "arn:aws:dynamodb:eu-central-1:045122203331:table/ddb-anmeldung-jaeger-lambda-cache"
	},
    {
		"Sid": "SNSPublishMessage",
		"Effect": "Allow",
		"Action": "sns:Publish",
		"Resource": "arn:aws:sns:eu-central-1:045122203331:topic-anmeldung-jaeger-bremen"
	}
  ]
}
EOF
}

# Policy Attachment on the role.

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

# Generates an archive from content, a file, or a directory of files.

data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/python/checkBremen"
  output_path = "${path.module}/python/checkBremen.zip"
}

# Create a lambda function
# In terraform ${path.module} is the current directory.
resource "aws_lambda_function" "terraform_lambda_func" {
  filename         = "${path.module}/python/checkBremen.zip"
  function_name    = "aj-checkBremen-lambda-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.7"
  depends_on       = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
  source_code_hash = data.archive_file.zip_the_python_code.output_base64sha256
  timeout          = 20
  environment {
    variables = {
      TZ = "Europe/Berlin"
    }
  }
}


output "teraform_aws_role_output" {
  value = aws_iam_role.lambda_role.name
}

output "teraform_aws_role_arn_output" {
  value = aws_iam_role.lambda_role.arn
}

output "teraform_logging_arn_output" {
  value = aws_iam_policy.iam_policy_for_lambda.arn
}
