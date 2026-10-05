# lambda-processor

Defines the AWS Lambda function(s) used for asynchronous/background
processing, along with their IAM roles and event source mappings.

## Usage

```hcl
module "lambda_processor" {
  source = "../../modules/lambda-processor"
}
```
