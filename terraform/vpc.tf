data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /20s inside the /16, private block starting at .0, public at .16 --
  # arbitrary but simple, room for az_count up to 16 before the two ranges
  # would collide.
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 16)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # Single NAT gateway (not one per AZ) -- a real cost/availability
  # tradeoff, deliberate for this project's demo/portfolio scope rather
  # than something a production account handling real traffic should copy
  # unmodified. Revisit alongside the same "demo scope" gaps
  # ../../agentforge-docs/docs/architecture/14-outstanding-gaps.md already
  # tracks for db/opensearch's single-replica StatefulSets.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for the EKS/AWS Load Balancer Controller to auto-discover
  # subnets for internal vs. internet-facing load balancers -- without
  # these, Kubernetes Service type=LoadBalancer / Ingress provisioning
  # silently fails to pick a subnet.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = var.tags
}
