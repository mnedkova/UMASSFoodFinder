resource "aws_iam_role" "lambda_role" {
name   = "Lambda_Function_Role"
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

resource "aws_iam_policy" "iam_policy_for_lambda" {
 name         = "aws_iam_policy_for_terraform_aws_lambda_role"
 path         = "/"
 description  = "AWS IAM Policy for managing aws lambda role"
 policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_policy" "iam_policy_for_S3" {
  name = "aws_iam_policy_for_lambda_to_access_S3"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::EXAMPLE-BUCKET/*"
      ]
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "secrets_manager_policy_doc" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:us-east-2:717279727567:secret:prod/foodfinder*"
    ]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "secrets_manager_policy" {
  name = "aws_iam_policy_for_lambda_to_access_secrets_manager"
  path = "/"
  policy = data.aws_iam_policy_document.secrets_manager_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "attach_iam_secrets_manager_policy_to_iam_role" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}


resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
 role        = aws_iam_role.lambda_role.name
 policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}

resource "aws_iam_role_policy_attachment" "attach_iam_S3_policy_to_iam_role" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_S3.arn
}

resource "terraform_data" "build_lambda_scraper" {
  provisioner "local-exec" {
    command = "../scripts/create_pkg.sh"
    working_dir = path.module
  }
}

data "archive_file" "zip_scraper" {
  depends_on = [ terraform_data.build_lambda_scraper ]
  type        = "zip"
  source_dir  = "${path.module}/lambda_dist_pkg"
  output_path = "${path.module}/scraper.zip"
}

resource "aws_lambda_function" "scraper_lambda" {
  filename                       = "${path.module}/scraper.zip"
  function_name                  = "scraper_lambda_function"
  role                           = aws_iam_role.lambda_role.arn
  handler                        = "index.lambda_handler"
  runtime                        = "python3.13"
  depends_on                     = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}