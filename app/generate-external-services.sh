#!/bin/bash

# Script to generate additional Kong mesh External Services
# This script creates external services for various endpoints

NAMESPACE="kuma-system"
MESH="demo"
OUTPUT_FILE="/Users/wally/projects/kind-flux/app/generated-external-services.yaml"

cat > "$OUTPUT_FILE" << 'EOF'
# Additional Generated Kong Mesh External Services
# Generated via script for testing and demonstration purposes

EOF

# Arrays of services to generate
declare -a test_services=(
    "test-api-1.example.com"
    "test-api-2.example.com"
    "test-api-3.example.com"
    "test-api-4.example.com"
    "test-api-5.example.com"
    "test-db-1.example.com"
    "test-db-2.example.com"
    "test-db-3.example.com"
    "test-cache-1.example.com"
    "test-cache-2.example.com"
)

declare -a mock_services=(
    "mock-payment.example.com"
    "mock-user.example.com" 
    "mock-inventory.example.com"
    "mock-notification.example.com"
    "mock-analytics.example.com"
    "mock-search.example.com"
    "mock-recommendation.example.com"
    "mock-catalog.example.com"
    "mock-order.example.com"
    "mock-shipping.example.com"
)

# Function to generate external service YAML
generate_external_service() {
    local name="$1"
    local address="$2"
    local protocol="${3:-http}"
    local port="${4:-443}"
    
    cat >> "$OUTPUT_FILE" << EOF
---
apiVersion: kuma.io/v1alpha1
kind: ExternalService
mesh: $MESH
metadata:
  name: $name
  namespace: $NAMESPACE
spec:
  tags:
    kuma.io/service: $name
    kuma.io/protocol: $protocol
  networking:
    address: $address:$port
    tls:
      enabled: true

EOF
}

# Generate test services
for i in "${!test_services[@]}"; do
    service_name="test-service-$((i+1))"
    generate_external_service "$service_name" "${test_services[$i]}" "http" "443"
done

# Generate mock services
for i in "${!mock_services[@]}"; do
    service_name="mock-service-$((i+1))"
    generate_external_service "$service_name" "${mock_services[$i]}" "http" "443"
done

echo "Generated additional external services in $OUTPUT_FILE"
