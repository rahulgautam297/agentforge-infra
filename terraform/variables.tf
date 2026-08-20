variable "aws_region" {
  description = "AWS region to provision into. Must be a region where both EKS and the Bedrock model(s) you intend to run are available -- see ../kubernetes/README.md's own note on Nova Micro's regional availability for why this bit the manual setup earlier."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name for the EKS cluster and the prefix for every other named resource this module creates."
  type        = string
  default     = "agentforge"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread public/private subnets across."
  type        = number
  default     = 3
}

variable "node_instance_types" {
  description = "Instance type(s) for the EKS managed node group. Sized for OpenSearch + execution-platform's resource requests (see ../kubernetes/opensearch.yaml's 500m/1Gi request, 2/2Gi limit) -- t3.medium is too small once OpenSearch, Temporal, and both app services are all scheduled."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_group_min_size" {
  type    = number
  default = 2
}

variable "node_group_max_size" {
  type    = number
  default = 4
}

variable "node_group_desired_size" {
  type    = number
  default = 2
}

variable "kubernetes_version" {
  description = "EKS control plane Kubernetes version."
  type        = string
  default     = "1.33"
}

variable "eks_namespace" {
  description = "Kubernetes namespace the execution-platform Pod Identity association targets -- must match the namespace ../helm/agentforge is installed into (e.g. `helm install agentforge . -n agentforge --create-namespace` -> \"agentforge\")."
  type        = string
  default     = "agentforge"
}

variable "execution_platform_service_account" {
  description = "ServiceAccount name the execution-platform Pod Identity association targets -- must match ../helm/agentforge's serviceAccount.name value (defaults to \"<release-name>-execution-platform\"; a release named \"agentforge\" -> \"agentforge-execution-platform\", this variable's default)."
  type        = string
  default     = "agentforge-execution-platform"
}

variable "bedrock_model_resource_pattern" {
  description = "Foundation-model ARN suffix the execution-platform Pod Identity role is authorized to invoke -- same scoping approach as the manually-created AgentForgeBedrockInvoke IAM policy (Nova-only, region-wildcarded), now as Terraform instead of console clicks. Change if you deploy an agent YAML declaring a different model.model_id."
  type        = string
  default     = "amazon.nova-*"
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default = {
    Project   = "agentforge"
    ManagedBy = "terraform"
  }
}
