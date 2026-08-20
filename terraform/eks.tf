module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access = true
  # Public+private (not public-only) so `kubectl` from a laptop still works
  # without a bastion/VPN, while node-to-control-plane traffic stays inside
  # the VPC -- fine for this project's demo/portfolio scope; a real
  # production cluster would usually turn endpoint_public_access off
  # entirely behind a VPN, per the same reasoning vpc.tf's single NAT
  # gateway comment already flags.
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    # Required in-cluster component for the aws_eks_pod_identity_association
    # in iam.tf below to actually work -- without this addon running,
    # pods have nothing to fetch credentials from even if the association
    # exists.
    eks-pod-identity-agent = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size
    }
  }

  tags = var.tags
}
