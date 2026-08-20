# kubernetes

**Phase:** 11

Kubernetes manifests for deploying AgentForge to a cluster -- a direct
translation of `../docker-compose.yml`'s topology (same 8 services, same
env vars, same ports), not a redesign. Plain manifests + Kustomize, not
Helm yet (see `../helm/README.md` for that layer, still Phase 11 scope but
not started here).

## What's here

| File | Translates from (docker-compose service) |
|---|---|
| `namespace.yaml` | -- (new: everything lives in the `agentforge` namespace) |
| `secrets.example.yaml` | the three passwords / bearer token in `../.env.example` |
| `db.yaml` | `db` |
| `temporal.yaml` | `temporal` |
| `opensearch.yaml` | `opensearch` |
| `control-plane.yaml` | `control-plane` |
| `execution-platform.yaml` | `execution-platform` |
| `frontend.yaml` | `frontend` |
| `prometheus.yaml` | `prometheus` |
| `grafana.yaml` | `grafana` |
| `ingress.example.yaml` | -- (new: compose had no ingress; browser hit `localhost` directly) |

## Prerequisites

- A cluster (`kind`/`minikube` for local testing, or a real one).
- `kubectl` and `kustomize` (or a `kubectl` new enough to have `-k` built in).
- The three app images built locally -- unlike the six third-party images
  (`timescale/timescaledb`, `temporalio/temporal`, `opensearchproject/opensearch`,
  `prom/prometheus`, `grafana/grafana`, and busybox for the init containers),
  `control-plane`/`execution-platform`/`frontend` are built from the sibling
  repos, same as docker-compose's `build: context: ../agentforge-*` does --
  there's no registry to pull them from yet:

  ```sh
  docker build -t agentforge/control-plane:local ../agentforge-control-plane
  docker build -t agentforge/execution-platform:local ../agentforge-agent-execution-platform
  docker build -t agentforge/frontend:local ../agentforge-frontend

  # kind only -- minikube uses `minikube image load` instead; a real
  # cluster needs these pushed to a real registry and the image refs in
  # control-plane.yaml/execution-platform.yaml/frontend.yaml updated to match.
  kind load docker-image agentforge/control-plane:local
  kind load docker-image agentforge/execution-platform:local
  kind load docker-image agentforge/frontend:local
  ```

## Deploy

`kustomization.yaml` lives at the repo root (alongside `docker-compose.yml`),
not in this directory -- see its own comment for why (it needs to reach
both `kubernetes/` and `observability/`, and Kustomize won't follow a
sibling-directory reference from inside `kubernetes/` alone).

```sh
cd ..   # agentforge-infra root
cp kubernetes/secrets.example.yaml kubernetes/secrets.yaml   # then edit the passwords/token for anything but a throwaway cluster
kubectl apply -k .
kubectl -n agentforge get pods -w      # db/opensearch/temporal need to go Ready before control-plane/execution-platform will
```

`control-plane`'s pod runs `alembic upgrade head` as part of its own
startup (same `CMD` as the container image, unchanged) -- give it a minute
on first boot before it reports Ready.

To reach it locally without an Ingress:

```sh
kubectl -n agentforge port-forward svc/frontend 3000:3000
kubectl -n agentforge port-forward svc/control-plane 8000:8000
kubectl -n agentforge port-forward svc/execution-platform 8001:8001
```

For anything past a port-forwarded smoke test, copy `ingress.example.yaml`
to `ingress.yaml`, fill in real hostnames for your cluster's ingress
controller, `kubectl apply -f ingress.yaml`, and update
`frontend.yaml`'s `frontend-public-urls` ConfigMap to match those same
hostnames -- see that file's own comment for why (those two env vars are
read by the browser, not server-to-server, so they can't be internal
Service DNS names).

## Known gaps (carried over from docker-compose, not introduced here)

This phase is a topology translation, not a hardening pass -- these are
pre-existing gaps this manifest set inherits rather than fixes, each
already called out in `../../agentforge-docs/docs/architecture/13-risks.md`
or the relevant manifest's own comment:

- **`frontend`'s image still runs `pnpm dev`**, a dev server, not a
  production `next build && next start`. Fixing this is an
  `agentforge-frontend` Dockerfile change, out of scope for an infra-repo
  manifest translation.
- **Temporal runs as its single-process embedded-SQLite dev-server**, not a
  real Temporal cluster/Temporal Cloud -- a pod restart loses all workflow
  history. See `temporal.yaml`'s comment.
- **No Postgres Row-Level Security, no read replicas** -- both explicitly
  deferred to "around Phase 11" by doc13, and still not built in this pass;
  this pass is the manifests, not the hardening those manifests make
  newly-relevant.
- **`db`/`opensearch` StatefulSets are single-replica** with no backup/restore
  story -- fine for the demo/dev scope this whole project has had through
  Phase 10, a real gap for anything meant to hold real data.
