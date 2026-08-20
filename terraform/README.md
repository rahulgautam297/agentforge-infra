# terraform

**Phase:** 11

Provisions the AWS infrastructure `../kubernetes/`/`../helm/agentforge`
deploy onto -- a VPC, an EKS cluster, ECR repositories for the three
sibling-repo images, and an IAM role for the execution-platform's Bedrock
access. This is the layer *beneath* Kubernetes: it provisions the cluster,
it does not deploy AgentForge itself -- that's `helm install`, run
afterward against the cluster this creates.

Built and validated against **Terraform 1.15.8**, AWS provider `~> 6.0`,
`terraform-aws-modules/vpc/aws ~> 5.0`, `terraform-aws-modules/eks/aws ~> 21.0`.

## What this provisions

| File | Creates |
|---|---|
| `vpc.tf` | VPC, public+private subnets across `var.az_count` AZs, one NAT gateway |
| `eks.tf` | EKS cluster, one managed node group, `coredns`/`kube-proxy`/`vpc-cni`/`eks-pod-identity-agent` addons |
| `ecr.tf` | Three ECR repos (`control-plane`, `execution-platform`, `frontend`) with a basic lifecycle policy |
| `iam.tf` | An IAM role + EKS Pod Identity association scoping the execution-platform's Bedrock access |

## Why Pod Identity, not static AWS keys

The local setup wired `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` into
`docker-compose.yml` from a manually-created IAM user and access key (see
`../helm/agentforge/values.yaml`'s `credentials.awsAccessKeyId`/
`awsSecretAccessKey`) -- fine for local dev, but a real cluster shouldn't
run on long-lived static credentials sitting in a Secret. `iam.tf`
provisions the same permission scope (`bedrock:InvokeModel`/
`InvokeModelWithResponseStream` on Nova models only) as an
[EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
association instead -- AWS's current (2026) recommended mechanism, simpler
than the older IRSA/OIDC-provider approach it's gradually superseding (no
per-role OIDC trust-policy JSON, no in-cluster ServiceAccount annotation
needed). `boto3`'s default credential chain inside `BedrockProvider` picks
up Pod Identity's injected credentials automatically -- the same
"let the SDK's own chain resolve it" design that already backs the local
static-key setup, so `providers/bedrock.py` itself needs zero changes
either way.

This only works end-to-end if `../helm/agentforge`'s execution-platform
ServiceAccount name/namespace match `var.execution_platform_service_account`/
`var.eks_namespace` below -- see `iam.tf`'s own comment and
`../helm/agentforge/values.yaml`'s `serviceAccount` block, which this
Terraform's defaults are written to match out of the box (a Helm release
named `agentforge`, installed into the `agentforge` namespace).

## Apply

```sh
cp terraform.tfvars.example terraform.tfvars   # then adjust region/cluster_name/etc.
terraform init
terraform plan
terraform apply
```

```sh
# after apply
$(terraform output -raw configure_kubectl)
kubectl get nodes

# push images -- see ecr.tf's own comment / ../helm/agentforge/README.md
terraform output ecr_repository_urls
```

Then install the Helm chart against the new cluster:

```sh
cd ../helm/agentforge
helm install agentforge . -n agentforge --create-namespace \
  --set image.controlPlane.repository=<ecr_repository_urls.control-plane> --set image.controlPlane.tag=<tag> \
  --set image.executionPlatform.repository=<ecr_repository_urls.execution-platform> --set image.executionPlatform.tag=<tag> \
  --set image.frontend.repository=<ecr_repository_urls.frontend> --set image.frontend.tag=<tag>
```

## Remote state

Not configured by default -- `versions.tf`'s `terraform {}` block has no
`backend` -- local state is fine for a first apply but shouldn't stay that
way once anyone besides you touches this. To switch to S3 + DynamoDB
locking:

```sh
aws s3api create-bucket --bucket <your-unique-bucket-name> --region us-east-1
aws dynamodb create-table --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

then add to `versions.tf`:

```hcl
backend "s3" {
  bucket         = "<your-unique-bucket-name>"
  key            = "agentforge/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-locks"
  encrypt        = true
}
```

and re-run `terraform init` to migrate existing local state.

## Known gaps

- **Single NAT gateway, not one per AZ** (`vpc.tf`) -- a real cost/
  availability tradeoff made for this project's demo/portfolio scope, not
  something a production account handling real traffic should copy
  unmodified.
- **Public + private EKS endpoint access both enabled** (`eks.tf`) -- lets
  `kubectl` work from a laptop without a bastion/VPN. A real production
  cluster would usually disable public access entirely.
- **No RDS, no managed OpenSearch** -- deliberate, matches
  [ADR-0006](../../agentforge-docs/docs/adr/0006-timescaledb-single-database.md)'s
  single self-hosted TimescaleDB design; this Terraform provisions the
  cluster those StatefulSets (`../kubernetes/db.yaml`,
  `../kubernetes/opensearch.yaml`) run inside, not a replacement for them.
- **Not validated against a real `terraform apply`** -- `terraform init`/
  `validate`/`fmt` all pass, but no live plan/apply has been run against a
  real AWS account from this environment (blocked by the same
  account-verification issue documented in
  [doc14](../../agentforge-docs/docs/architecture/14-outstanding-gaps.md)).
- **No `terraform-docs`-generated variable/output reference** -- read
  `variables.tf`/`outputs.tf` directly.
