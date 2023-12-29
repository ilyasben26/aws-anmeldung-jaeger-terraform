resource "aws_iam_policy" "iam_policy_for_lambda_getData" {

  name        = "aws_iam_policy_for_terraform_aws_lambda_role_getData"
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
          "Sid" : "S3GetData",
          "Effect" : "Allow",
          "Action" : "s3:GetObject",
          "Resource" : "${aws_s3_bucket.aj_bucket.arn}/data.json"
        }
      ]
    }
  )
}

resource "aws_iam_role" "lambda_role_getData" {
  name = "aj_lambda_role_getData"
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

# Policy Attachment on the role.

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role_getData" {
  role       = aws_iam_role.lambda_role_getData.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda_getData.arn
}

# Generates an archive from content, a file, or a directory of files.

data "archive_file" "zip_the_python_code_getData" {
  type        = "zip"
  source_dir  = "${path.module}/python/getData"
  output_path = "${path.module}/python/getData.zip"
}

# Create a lambda function
# In terraform ${path.module} is the current directory.
resource "aws_lambda_function" "terraform_lambda_func_getData" {
  filename         = "${path.module}/python/getData.zip"
  function_name    = "aj-getData-lambda-function"
  role             = aws_iam_role.lambda_role_getData.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.7"
  depends_on       = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role_getData]
  source_code_hash = data.archive_file.zip_the_python_code_getData.output_base64sha256

}
