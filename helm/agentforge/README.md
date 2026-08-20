# agentforge (Helm chart)

Parameterized Helm chart for AgentForge -- same 8-service topology as
`../../kubernetes/*.yaml` and `../../docker-compose.yml`, packaged for
repeatable, values-driven installs instead of a fixed manifest set. Built
and validated against **Helm 4.2.4**; chart authoring (Chart API v2,
`templates/`, `values.yaml`) is unchanged between Helm 3 and 4 -- only
CLI/plugin/SDK behavior differs, none of which this chart touches.

## Prerequisites

- A cluster (`kind`/`minikube` for local testing, or a real one).
- `helm` v3.14+ (anything supporting Chart API v2; developed against Helm 4.2.4).
- The three sibling-repo images built and pushed somewhere this cluster can
  pull from -- unlike `kubernetes/`'s `kind load docker-image` shortcut,
  a Helm install is meant to be repeatable against a real registry:

  ```sh
  docker build -t <registry>/agentforge-control-plane:<tag> ../../agentforge-control-plane
  docker build -t <registry>/agentforge-execution-platform:<tag> ../../agentforge-agent-execution-platform
  docker build -t <registry>/agentforge-frontend:<tag> ../../agentforge-frontend
  docker push <registry>/agentforge-control-plane:<tag>
  docker push <registry>/agentforge-execution-platform:<tag>
  docker push <registry>/agentforge-frontend:<tag>
  ```

  For a local `kind` smoke test instead, build with the `agentforge/*:local`
  names `values.yaml` already defaults to and `kind load docker-image` them,
  same as `kubernetes/README.md`'s approach -- no registry needed.

## Install

```sh
helm lint .
helm install agentforge . -n agentforge --create-namespace \
  --set image.controlPlane.repository=<registry>/agentforge-control-plane \
  --set image.controlPlane.tag=<tag> \
  --set image.executionPlatform.repository=<registry>/agentforge-execution-platform \
  --set image.executionPlatform.tag=<tag> \
  --set image.frontend.repository=<registry>/agentforge-frontend \
  --set image.frontend.tag=<tag>
kubectl -n agentforge get pods -w
```

Or write a `values-prod.yaml` (gitignored, never commit real credentials)
overriding `credentials.*` and `image.*`, and install with
`helm install agentforge . -n agentforge --create-namespace -f values-prod.yaml`.

The chart does **not** template a `Namespace` resource -- `--create-namespace`
owns that, so `helm uninstall` never risks cascading into deleting the
namespace itself along with everything else in it.

## Upgrading

```sh
helm upgrade agentforge . -n agentforge -f values-prod.yaml
```

Prometheus's Deployment carries a `checksum/config` pod annotation derived
from `files/observability/prometheus.yml`'s content, so editing that file
and re-running `helm upgrade` correctly rolls the Prometheus pod even though
a plain ConfigMap volume mount wouldn't trigger one on its own. Grafana's
ConfigMaps don't have the same annotation yet (see "Known gaps" below).

## Values

See `values.yaml`'s own inline comments for the full set -- the shape
mirrors `kubernetes/*.yaml`'s hardcoded values almost exactly, just made
overridable: `image.*` (repo/tag per service), `credentials.*` (the same
three dev passwords `../.env.example` ships, plus Phase 10's AWS Bedrock
fields), `*.resources`/`*.replicas`/`*.storage` per component, and
`ingress.*` (disabled by default, same reasoning as
`kubernetes/ingress.example.yaml` -- which controller/hostnames vary per
cluster).

`credentials.existingSecret`: set this to reference a Secret you created
out-of-band (with the same 8 keys `templates/secret.yaml` would otherwise
generate -- see that file) instead of letting the chart create one from
`credentials.postgresPassword`/etc. -- the standard Helm pattern for not
letting a values file be the only place a real production secret lives.

## Keeping `files/observability/` in sync

`files/observability/` is a **copy** of `../../observability/`, not a live
reference -- Helm's `.Files.Get` can only read files inside the chart's own
directory (same restriction Kustomize's default load restrictor applies to
`kubernetes/kustomization.yaml`, which is why that one lives at the infra
repo root instead). Two of the four files were also modified beyond a
plain copy -- `files/observability/prometheus.yml`'s scrape target and
`files/observability/grafana/provisioning/datasources/prometheus.yml`'s
datasource `url` both reference `{{ include "agentforge.fullname" . }}`
instead of the bare `execution-platform`/`prometheus` hostnames
`../../observability/`'s originals use, since Helm's release-prefixed
Service names (e.g. `agentforge-execution-platform`, not
`execution-platform`) mean the unmodified files would point Prometheus
and Grafana at Services that don't exist. If `../../observability/`'s
*content* changes (e.g. a new scrape job, a new Grafana dashboard panel),
re-copy the affected file into `files/` and reapply that one templating
change by hand -- there's no automated sync today.

## Known gaps

Same three carried over from `kubernetes/README.md` (this chart doesn't
fix what the manifests it's built from didn't already have):
- `frontend`'s image still runs `pnpm dev`, a dev server, not a production build.
- Temporal runs as the single-process embedded-SQLite dev-server, not a real cluster.
- No Postgres Row-Level Security, no read replicas, no `db`/`opensearch` backup story.

Chart-specific, not yet done:
- No `values.schema.json` for `helm install --set` typo validation.
- Grafana's three ConfigMaps have no `checksum/config` annotation yet
  (Prometheus's does) -- editing an observability file under
  `files/observability/grafana/` and re-running `helm upgrade` won't roll
  the Grafana pod on its own; `kubectl rollout restart deployment/agentforge-grafana`
  after upgrading is the workaround until this is added.
- Not yet published as a chart repo / OCI artifact (`helm package` +
  `helm push` to somewhere) -- installed today straight from this
  checked-out directory only.
