output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ecr_repository_urls" {
  description = "Push targets for the three sibling-repo images -- see ecr.tf's own comment."
  value       = { for k, v in aws_ecr_repository.app : k => v.repository_url }
}

output "execution_platform_bedrock_role_arn" {
  description = "The Pod Identity role execution-platform assumes for Bedrock calls -- confirm this matches what `aws eks describe-pod-identity-association` reports if debugging a credentials issue."
  value       = aws_iam_role.execution_platform.arn
}
