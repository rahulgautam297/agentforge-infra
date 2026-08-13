# agentforge-infra

**Status:** Not yet implemented — see `../agentforge-docs/docs/architecture/12-implementation-plan.md`. Phase 1 (Docker Compose), Phase 11 (Kubernetes/Helm/Terraform).

## Purpose

This repo will hold the infrastructure definitions for AgentForge: a Docker
Compose stack for local development, and Kubernetes manifests, Helm charts,
and Terraform modules for production-style deployment. The local Compose
stack assumes all 7 AgentForge repos are cloned as sibling directories (see
`../agentforge-docs/workspace-setup.md`), and its build contexts reference
sibling repos such as `../agentforge-frontend` directly. See
`../agentforge-docs/docs/architecture/02-component-responsibilities.md` and
`../agentforge-docs/docs/architecture/06-repository-structure.md` for how
this repo fits into the wider polyrepo.

This repo holds four subfolders — see each subfolder's own README for its
phase and purpose:

- [`docker/`](./docker/README.md) — Phase 1
- [`kubernetes/`](./kubernetes/README.md) — Phase 11
- [`helm/`](./helm/README.md) — Phase 11
- [`terraform/`](./terraform/README.md) — Phase 11

## Depends on

- All other AgentForge repos existing as sibling directories, for local
  Docker Compose builds. Nothing at runtime in production — production
  deployments reference published container images instead.

## Related documentation

- [Architecture overview](../agentforge-docs/docs/architecture/01-overview.md)
- [Component responsibilities](../agentforge-docs/docs/architecture/02-component-responsibilities.md)
- [Repository structure](../agentforge-docs/docs/architecture/06-repository-structure.md)
- [Workspace setup](../agentforge-docs/workspace-setup.md)
