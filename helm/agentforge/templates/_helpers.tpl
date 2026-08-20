{{/*
Fully qualified app name -- release-scoped so two installs of this chart in
the same cluster (different namespaces or release names) never collide.
*/}}
{{- define "agentforge.fullname" -}}
{{- .Release.Name -}}
{{- end -}}

{{/*
Standard labels, applied to every resource this chart creates.
*/}}
{{- define "agentforge.labels" -}}
app.kubernetes.io/part-of: agentforge
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/*
Per-component selector labels -- pass the component name as the template
argument, e.g. {{ include "agentforge.selectorLabels" (dict "component" "control-plane") }}.
*/}}
{{- define "agentforge.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ $.Release.Name }}
{{- end -}}

{{/*
Name of the Secret holding credentials -- either the user-supplied
existingSecret, or the one templates/secret.yaml creates from
.Values.credentials.*.
*/}}
{{- define "agentforge.secretName" -}}
{{- if .Values.credentials.existingSecret -}}
{{- .Values.credentials.existingSecret -}}
{{- else -}}
{{- printf "%s-credentials" (include "agentforge.fullname" .) -}}
{{- end -}}
{{- end -}}
