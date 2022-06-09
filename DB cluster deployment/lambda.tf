/*
I had created S3 bucket to store hello.zip file which contains a simple handler method
in Node.js. Then I started setting IAM role policies and creating lambda resources. 
*/

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_role.id
  policy = file("IAM/lambda_policy.json")
}
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = file("IAM/lambda_assume_role_policy.json")
}

resource "aws_lambda_function" "test_lambda" {
  function_name = "hello"
  s3_bucket     = data.aws_s3_object.test_lambda.bucket
  s3_key        = data.aws_s3_object.test_lambda.key
  role          = aws_iam_role.lambda_role.arn
  handler       = "hello.handler"
  runtime       = "nodejs12.x"
}
# Created CloudWatch rule and attached Lambda for execution
resource "aws_cloudwatch_event_rule" "ec2-rule" {
  name        = "ec2-rule"
  description = "Trigger Stop Instance every 5 min"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda-func" {
  rule      = aws_cloudwatch_event_rule.ec2-rule.name
  target_id = "hello"
  arn       = aws_lambda_function.test_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2-rule.arn
}
*/
