# One repository per sibling-repo image the Kubernetes/Helm layer needs
# pushed somewhere -- see ../helm/agentforge/README.md's "Prerequisites"
# section, which otherwise only offers the kind-load-docker-image local
# shortcut. Push targets after `terraform apply`:
#   docker tag agentforge/control-plane:local <repository_url>:<tag>
#   docker push <repository_url>:<tag>
# then point helm install's image.controlPlane.repository/tag (or the
# equivalent kubernetes/*.yaml edit) at it.
locals {
  ecr_repositories = ["control-plane", "execution-platform", "frontend"]
}

resource "aws_ecr_repository" "app" {
  for_each = toset(local.ecr_repositories)

  name                 = "${var.cluster_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# Keep the last 10 tagged images per repo; untagged images (superseded by
# a re-push of the same tag) expire after 1 day -- same "demo/portfolio
# scope, not a prescription for a real production retention policy"
# caveat as vpc.tf's single NAT gateway.
resource "aws_ecr_lifecycle_policy" "app" {
  for_each = aws_ecr_repository.app

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 10 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
