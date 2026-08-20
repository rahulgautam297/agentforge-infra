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

{{/*
Name of execution-platform's ServiceAccount -- either the user-supplied
serviceAccount.name, or "<release-name>-execution-platform" by default.
This is the name ../../terraform/iam.tf's aws_eks_pod_identity_association
must match (see that file's execution_platform_service_account variable)
for Bedrock credentials to actually reach the pod on a real EKS cluster.
*/}}
{{- define "agentforge.executionPlatformServiceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-execution-platform" (include "agentforge.fullname" .) -}}
{{- end -}}
{{- end -}}
