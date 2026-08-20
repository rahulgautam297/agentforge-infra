terraform {
  required_version = ">= 1.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state is deliberately not configured here -- the S3 bucket +
  # DynamoDB lock table it would point at are themselves account-specific
  # bootstrapping (see README.md's "Remote state" section for the two
  # `aws s3api create-bucket`/`aws dynamodb create-table` commands and the
  # backend block to add once they exist). Local state is fine for a first
  # apply; don't leave it that way once anyone besides you touches this.
}

provider "aws" {
  region = var.aws_region
}
