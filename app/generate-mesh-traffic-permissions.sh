#!/bin/bash

# Script to generate MeshTrafficPermissions for all External Services
# This script creates comprehensive traffic permissions for Kong mesh

NAMESPACE="kuma-system"
MESH="demo"
OUTPUT_FILE="/Users/wally/projects/kind-flux/app/generated-mesh-traffic-permissions.yaml"

cat > "$OUTPUT_FILE" << 'EOF'
# Generated Kong Mesh Traffic Permissions
# This file contains MeshTrafficPermissions for all external services

EOF

# Function to generate MeshTrafficPermission YAML
generate_traffic_permission() {
    local permission_name="$1"
    local service_name="$2"
    local from_service1="$3"
    local from_service2="$4"
    
    cat >> "$OUTPUT_FILE" << EOF
---
apiVersion: kuma.io/v1alpha1
kind: MeshTrafficPermission
metadata:
  name: $permission_name
  namespace: $NAMESPACE
  labels:
    kuma.io/mesh: $MESH
spec:
  targetRef:
    kind: MeshSubset
    tags:
      kuma.io/service: $service_name
  from:
  - targetRef:
      kind: MeshSubset
      tags:
        kuma.io/service: $from_service1
    default:
      action: Allow
  - targetRef:
      kind: MeshSubset
      tags:
        kuma.io/service: $from_service2
    default:
      action: Allow

EOF
}

# Generate permissions for multiple source services accessing external services
declare -a source_services=(
    "netshoot_httpbin_svc_80"
    "httpbin_httpbin_svc_80"
    "kube-state-metrics"
    "kong-proxy"
    "kong-admin"
)

declare -a external_services=(
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

# Generate traffic permissions for each combination of source and external service
for source_service in "${source_services[@]}"; do
    for external_service in "${external_services[@]}"; do
        # Clean up service names for permission names
        clean_source=$(echo "$source_service" | tr '_' '-' | tr '.' '-')
        clean_external=$(echo "$external_service" | tr '_' '-' | tr '.' '-')
        permission_name="allow-${clean_source}-to-${clean_external}"
        
        generate_traffic_permission "$permission_name" "$external_service" "$source_service" "default"
    done
done

# Generate permissions for generated test services
for i in {1..20}; do
    for source_service in "${source_services[@]}"; do
        clean_source=$(echo "$source_service" | tr '_' '-' | tr '.' '-')
        permission_name="allow-${clean_source}-to-test-service-${i}"
        generate_traffic_permission "$permission_name" "test-service-${i}" "$source_service" "default"
        
        permission_name="allow-${clean_source}-to-mock-service-${i}"
        generate_traffic_permission "$permission_name" "mock-service-${i}" "$source_service" "default"
    done
done

echo "Generated comprehensive MeshTrafficPermissions in $OUTPUT_FILE"
