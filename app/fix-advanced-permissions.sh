#!/bin/bash

# Script to generate fixed advanced MeshTrafficPermissions without wildcards
# Kong mesh doesn't support wildcard patterns in service tags

NAMESPACE="kuma-system"
MESH="demo"
OUTPUT_FILE="/Users/wally/projects/kind-flux/app/fixed-advanced-mesh-traffic-permissions.yaml"

cat > "$OUTPUT_FILE" << 'EOF'
# Fixed Advanced Kong Mesh Traffic Permissions
# This file contains specialized MeshTrafficPermissions for specific scenarios
# No wildcard patterns - using specific service names

EOF

# Get list of all external services from the existing files
declare -a external_services=(
    "httpbin-external"
    "jsonplaceholder-external"
    "github-api-external"
    "google-external"
    "stackoverflow-external"
    "reddit-api-external"
    "docker-hub-external"
    "npm-registry-external"
    "pypi-external"
    "kubernetes-io-external"
    "aws-api-external"
    "azure-api-external"
    "gcp-api-external"
    "terraform-registry-external"
    "helm-charts-external"
    "prometheus-external"
    "grafana-external"
    "jaeger-external"
    "elastic-external"
    "mongodb-external"
    "redis-external"
    "postgresql-external"
    "mysql-external"
    "cassandra-external"
    "kafka-external"
    "rabbitmq-external"
    "jenkins-external"
    "gitlab-external"
    "bitbucket-external"
    "confluence-external"
    "jira-external"
    "slack-api-external"
    "discord-api-external"
    "teams-api-external"
    "zoom-api-external"
    "notion-api-external"
    "trello-api-external"
    "asana-api-external"
    "monday-api-external"
    "spotify-api-external"
    "youtube-api-external"
    "twitter-api-external"
    "facebook-api-external"
    "instagram-api-external"
    "linkedin-api-external"
    "stripe-api-external"
    "paypal-api-external"
    "square-api-external"
    "shopify-api-external"
    "woocommerce-api-external"
    "magento-api-external"
    "salesforce-api-external"
    "hubspot-api-external"
    "mailchimp-api-external"
    "sendgrid-api-external"
    "twilio-api-external"
    "nexmo-api-external"
    "auth0-api-external"
    "okta-api-external"
    "firebase-api-external"
    "supabase-api-external"
    "planetscale-api-external"
    "heroku-api-external"
    "vercel-api-external"
    "netlify-api-external"
    "cloudflare-api-external"
    "fastly-api-external"
    "datadog-api-external"
    "newrelic-api-external"
    "splunk-api-external"
    "pagerduty-api-external"
    "opsgenie-api-external"
    "sentry-api-external"
    "rollbar-api-external"
    "bugsnag-api-external"
    "honeybadger-api-external"
    "circleci-api-external"
    "travis-ci-external"
    "github-actions-external"
    "gitlab-ci-external"
    "codeship-api-external"
    "buildkite-api-external"
    "semaphore-api-external"
    "terraform-cloud-external"
    "ansible-galaxy-external"
    "puppet-forge-external"
    "chef-supermarket-external"
    "vagrant-cloud-external"
    "packer-registry-external"
    "consul-external"
    "vault-external"
    "nomad-external"
    "etcd-external"
    "istio-external"
    "linkerd-external"
    "envoy-external"
    "traefik-external"
    "nginx-external"
    "apache-external"
    "haproxy-external"
    "caddy-external"
    "certbot-external"
    "letsencrypt-external"
)

# Add test and mock services
for i in {1..10}; do
    external_services+=("test-service-${i}")
    external_services+=("mock-service-${i}")
done

# Function to generate traffic permission for observability access
generate_observability_permission() {
    local service="$1"
    cat >> "$OUTPUT_FILE" << EOF
---
apiVersion: kuma.io/v1alpha1
kind: MeshTrafficPermission
metadata:
  name: allow-observability-to-${service}
  namespace: $NAMESPACE
  labels:
    kuma.io/mesh: $MESH
spec:
  targetRef:
    kind: MeshSubset
    tags:
      kuma.io/service: $service
  from:
  - targetRef:
      kind: MeshSubset
      tags:
        app.kubernetes.io/name: kube-state-metrics
    default:
      action: Allow
  - targetRef:
      kind: MeshSubset
      tags:
        app: prometheus
    default:
      action: Allow
  - targetRef:
      kind: MeshSubset
      tags:
        app: grafana
    default:
      action: Allow

EOF
}

# Function to generate traffic permission for admin access
generate_admin_permission() {
    local service="$1"
    cat >> "$OUTPUT_FILE" << EOF
---
apiVersion: kuma.io/v1alpha1
kind: MeshTrafficPermission
metadata:
  name: allow-admin-to-${service}
  namespace: $NAMESPACE
  labels:
    kuma.io/mesh: $MESH
spec:
  targetRef:
    kind: MeshSubset
    tags:
      kuma.io/service: $service
  from:
  - targetRef:
      kind: MeshSubset
      tags:
        role: admin
    default:
      action: Allow
  - targetRef:
      kind: MeshSubset
      tags:
        user-type: admin
    default:
      action: Allow

EOF
}

# Generate observability permissions for key monitoring services
declare -a monitoring_services=(
    "prometheus-external"
    "grafana-external"
    "jaeger-external"
    "elastic-external"
    "datadog-api-external"
    "newrelic-api-external"
    "splunk-api-external"
)

for service in "${monitoring_services[@]}"; do
    generate_observability_permission "$service"
done

# Generate admin permissions for critical infrastructure services  
declare -a admin_services=(
    "aws-api-external"
    "azure-api-external"
    "gcp-api-external"
    "kubernetes-io-external"
    "vault-external"
    "consul-external"
    "istio-external"
    "linkerd-external"
    "nginx-external"
)

for service in "${admin_services[@]}"; do
    generate_admin_permission "$service"
done

echo "Generated fixed advanced MeshTrafficPermissions in $OUTPUT_FILE"
