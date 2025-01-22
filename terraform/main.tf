data "aws_iam_policy_document" "lambda_role_policy_doc" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "lambda_role" {
  name   = "Lambda_Function_Role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_policy_doc.json
}

data "aws_iam_policy_document" "iam_policy_for_lambda_doc" {
  statement {
    actions = [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents",
    ]
    effect = "Allow"
    resources = ["arn:aws:logs:*:*:*"]

  }
}

resource "aws_iam_policy" "iam_policy_for_lambda" {
 name         = "aws_iam_policy_for_terraform_aws_lambda_role"
 path         = "/"
 description  = "AWS IAM Policy for managing aws lambda role"
 policy = data.aws_iam_policy_document.iam_policy_for_lambda_doc.json
}

data "aws_iam_policy_document" "iam_policy_for_S3_doc" {
  statement {
    actions = [ 
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]
    effect = "Allow"
    resources = [ "arn:aws:s3:::umassdininginfo/*" ]
  }
}


resource "aws_iam_policy" "iam_policy_for_S3" {
  name = "aws_iam_policy_for_lambda_to_access_S3"
  path = "/"
  policy = data.aws_iam_policy_document.iam_policy_for_S3_doc.json
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
    interpreter = ["/bin/bash", "-c"]
  }
  triggers_replace = {
    dir_sha1    = sha1(join("", [for f in fileset(path.module, "../lambdas/scraper/**") : filesha1(f)]))
  }
}

data "archive_file" "zip_scraper" {
  depends_on = [ terraform_data.build_lambda_scraper ]
  type        = "zip"
  source_dir  = "${path.module}/lambda_dist_pkg"
  output_path = "${path.module}/scraper.zip"
}

resource "aws_lambda_function" "scraper_lambda" {
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
  filename      = "${path.module}/scraper.zip"
  function_name = "scraper_lambda_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.13"
  timeout       = 300

}

resource "aws_iam_role" "scraper_scheduler_role" {
  name = "ScraperSchedulerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "scraper_invoke_policy" {
  name = "ScraperInvokeLambdaPolicy"
  role = aws_iam_role.scraper_scheduler_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowEventBridgeToInvokeLambda",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Effect" : "Allow",
        "Resource" : aws_lambda_function.scraper_lambda.arn
      }
    ]
  })
}

resource "aws_scheduler_schedule" "scraper_lambda_schedule" {
  name = "ScraperLambdaSchedule"
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression = "cron(5 0 * * ? *)"
  schedule_expression_timezone = "America/New_York"
  target {
    arn = aws_lambda_function.scraper_lambda.arn
    role_arn = aws_iam_role.scraper_scheduler_role.arn
    input = jsonencode({
      "input": "This message was sent using EventBridge Scheduler!"
    })
  }
}
