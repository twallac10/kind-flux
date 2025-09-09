#!/bin/bash

# Script to generate role-based and time-based MeshTrafficPermissions
# This adds more sophisticated access patterns

NAMESPACE="kuma-system"
MESH="demo"
OUTPUT_FILE="/Users/wally/projects/kind-flux/app/role-based-mesh-traffic-permissions.yaml"

cat > "$OUTPUT_FILE" << 'EOF'
# Role-Based Kong Mesh Traffic Permissions
# This file contains specialized MeshTrafficPermissions for different roles and use cases

EOF

# Function to generate role-based MeshTrafficPermission
generate_role_permission() {
    local permission_name="$1"
    local target_service="$2"
    local role="$3"
    local environment="$4"
    
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
      kuma.io/service: $target_service
  from:
  - targetRef:
      kind: MeshSubset
      tags:
        role: $role
        env: $environment
    default:
      action: Allow

EOF
}

# Define roles and environments
declare -a roles=("developer" "qa" "devops" "admin" "security" "architect" "manager" "intern")
declare -a environments=("development" "testing" "staging" "production" "sandbox" "demo")

# Key external services that different roles need access to
declare -a dev_services=(
    "github-api-external"
    "gitlab-external"
    "jenkins-external"
    "docker-hub-external"
    "npm-registry-external"
    "pypi-external"
    "terraform-registry-external"
)

declare -a qa_services=(
    "httpbin-external"
    "jsonplaceholder-external"
    "github-api-external"
    "slack-api-external"
    "jira-external"
)

declare -a devops_services=(
    "aws-api-external"
    "azure-api-external"
    "gcp-api-external"
    "terraform-cloud-external"
    "ansible-galaxy-external"
    "consul-external"
    "vault-external"
    "prometheus-external"
    "grafana-external"
    "datadog-api-external"
)

declare -a admin_services=(
    "kubernetes-io-external"
    "vault-external"
    "consul-external"
    "istio-external"
    "linkerd-external"
    "traefik-external"
    "nginx-external"
)

# Generate permissions for developers
for env in "${environments[@]}"; do
    for service in "${dev_services[@]}"; do
        permission_name="allow-developer-${env}-to-${service}"
        generate_role_permission "$permission_name" "$service" "developer" "$env"
    done
done

# Generate permissions for QA
for env in "${environments[@]}"; do
    for service in "${qa_services[@]}"; do
        permission_name="allow-qa-${env}-to-${service}"
        generate_role_permission "$permission_name" "$service" "qa" "$env"
    done
done

# Generate permissions for DevOps
for env in "${environments[@]}"; do
    for service in "${devops_services[@]}"; do
        permission_name="allow-devops-${env}-to-${service}"
        generate_role_permission "$permission_name" "$service" "devops" "$env"
    done
done

# Generate permissions for Admins
for env in "${environments[@]}"; do
    for service in "${admin_services[@]}"; do
        permission_name="allow-admin-${env}-to-${service}"
        generate_role_permission "$permission_name" "$service" "admin" "$env"
    done
done

# Generate cross-role permissions for essential services
declare -a essential_services=("kubernetes-io-external" "github-api-external" "slack-api-external")

for role in "${roles[@]}"; do
    for env in "${environments[@]}"; do
        for service in "${essential_services[@]}"; do
            permission_name="allow-${role}-${env}-essential-${service}"
            generate_role_permission "$permission_name" "$service" "$role" "$env"
        done
    done
done

echo "Generated role-based MeshTrafficPermissions in $OUTPUT_FILE"
