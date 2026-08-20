# Production replacement for the manual AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY
# wizard flow used to get local Bedrock working -- an EKS Pod Identity
# association instead of static credentials sitting in a Secret/.env. Same
# permission scope as the manually-created AgentForgeBedrockInvoke IAM
# policy (bedrock:InvokeModel[WithResponseStream] on Nova models only,
# nothing else), now provisioned declaratively instead of console clicks.
#
# Once this is applied, ../helm/agentforge should be installed with
# credentials.awsAccessKeyId/awsSecretAccessKey left empty -- boto3's
# default credential chain inside BedrockProvider picks up Pod Identity's
# injected credentials automatically, the same "let the SDK's own chain
# resolve it" design providers/bedrock.py already relies on for a real
# AWS-hosted service. Requires ../helm/agentforge's execution-platform
# ServiceAccount name/namespace to match var.execution_platform_service_account
# /var.eks_namespace below -- see that chart's serviceAccount.name value.
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution_platform" {
  name               = "${var.cluster_name}-execution-platform-bedrock"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "bedrock_invoke" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = ["arn:aws:bedrock:*::foundation-model/${var.bedrock_model_resource_pattern}"]
  }
}

resource "aws_iam_role_policy" "bedrock_invoke" {
  name   = "bedrock-invoke"
  role   = aws_iam_role.execution_platform.id
  policy = data.aws_iam_policy_document.bedrock_invoke.json
}

resource "aws_eks_pod_identity_association" "execution_platform" {
  cluster_name    = module.eks.cluster_name
  namespace       = var.eks_namespace
  service_account = var.execution_platform_service_account
  role_arn        = aws_iam_role.execution_platform.arn

  tags = var.tags
}
