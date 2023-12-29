# IAM policy for logging lambda
resource "aws_iam_policy" "iam_policy_for_lambda" {

  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "LoggingCloudWatch",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:*:*:*",
          "Effect" : "Allow"
        },
        {
          "Sid" : "S3PutData",
          "Effect" : "Allow",
          "Action" : "s3:PutObject",
          "Resource" : "${aws_s3_bucket.aj_bucket.arn}/data.json"
        },
        {
          "Sid" : "DDBGetPutCache",
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:GetItem",
            "dynamodb:PutItem"
          ],
          "Resource" : "arn:aws:dynamodb:eu-central-1:045122203331:table/ddb-anmeldung-jaeger-lambda-cache"
        },
        {
          "Sid" : "SNSPublishMessage",
          "Effect" : "Allow",
          "Action" : "sns:Publish",
          "Resource" : "arn:aws:sns:eu-central-1:045122203331:topic-anmeldung-jaeger-bremen"
        }
      ]
    }
  )
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
