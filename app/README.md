# Kong Mesh External Services & Traffic Permissions - Kustomize Setup

This setup generates approximately 100+ Kong mesh External Services and 965 MeshTrafficPermissions using Kustomize for comprehensive testing and demonstration purposes.

## Files Overview

### External Services (124 total)
- `externalservice.yaml` - Contains 103 hand-crafted external services for popular APIs and services
- `generated-external-services.yaml` - Contains 20 additional programmatically generated external services
- `external-service-base.yaml` - Base template for external services
- `generate-external-services.sh` - Bash script that generates additional external services

### MeshTrafficPermissions (965 total)
- `mesh-traffic-permissions.yaml` - Contains 21 basic traffic permissions for core services
- `generated-mesh-traffic-permissions.yaml` - Contains 610 comprehensive traffic permissions for all service combinations
- `advanced-mesh-traffic-permissions.yaml` - Contains 16 specialized permissions for observability, admin access (⚠️ **Fixed**: removed wildcard patterns)
- `role-based-mesh-traffic-permissions.yaml` - Contains 318 role-based permissions for different user roles and environments
- `generate-mesh-traffic-permissions.sh` - Script for generating comprehensive traffic permissions
- `generate-role-based-permissions.sh` - Script for generating role-based traffic permissions

### Configuration Files
- `kustomization.yaml` - Main Kustomize configuration that includes all resources
- `kustomization-generators.yaml` - Alternative Kustomize configuration showing generator patterns
- `netshoot.yaml` - Contains 1 additional external service example

## Total Resources: 1,089
- **124 External Services**
- **965 MeshTrafficPermissions**

### ⚠️ **Important: Kong Mesh Tag Validation**

Kong mesh has strict validation rules for service tags:
- **Tag values must consist of alphanumeric characters, dots, dashes and underscores only**
- **No wildcard patterns (`*`, `?`) are allowed**
- **Service names must be exact matches**

**Fixed Issues:**
- Removed wildcard patterns like `"*-external"` and `"*-api-external"`
- Replaced with specific service names for proper validation
- All service tags now comply with Kong mesh validation requirements

### Categories of External Services Created:

1. **Development & API Testing** (10 services)
   - httpbin, jsonplaceholder, github-api, etc.

2. **Cloud Providers** (3 services)
   - AWS, Azure, GCP APIs

3. **Container & Package Registries** (8 services)
   - Docker Hub, NPM, PyPI, Helm Charts, etc.

4. **Observability & Monitoring** (15 services)
   - Prometheus, Grafana, Jaeger, Elastic, DataDog, etc.

5. **Databases & Data Stores** (6 services)
   - MongoDB, Redis, PostgreSQL, MySQL, Cassandra, etc.

6. **Communication & Messaging** (10 services)
   - Slack, Discord, Kafka, RabbitMQ, Twilio, etc.

7. **Development Tools** (15 services)
   - Jenkins, GitLab, Bitbucket, JIRA, Confluence, etc.

8. **Payment & E-commerce** (8 services)
   - Stripe, PayPal, Shopify, Salesforce, etc.

9. **Authentication & Security** (5 services)
   - Auth0, Okta, Firebase, Vault, etc.

10. **Cloud Services & Hosting** (12 services)
    - Heroku, Vercel, Netlify, Cloudflare, etc.

11. **CI/CD & DevOps** (15 services)
    - CircleCI, Travis CI, GitHub Actions, Terraform, Ansible, etc.

12. **Infrastructure & Service Mesh** (10 services)
    - Istio, Linkerd, Envoy, Traefik, NGINX, etc.

13. **Generated Test Services** (20 services)
    - Mock APIs, test databases, and cache services

### Categories of MeshTrafficPermissions Created:

1. **Basic Service-to-Service** (21 permissions)
   - Core services accessing external APIs

2. **Comprehensive Source-to-Target** (610 permissions)
   - All source services to all external services combinations

3. **Advanced Pattern-Based** (19 permissions)
   - Observability access patterns
   - Admin access to all external services
   - Environment-based access (dev, staging, prod)
   - Component-based access (CI/CD, frontend, backend)

4. **Role-Based Access Control** (318 permissions)
   - Developer, QA, DevOps, Admin roles
   - Environment-specific access
   - Cross-role essential service access

## Usage

### Build and Apply
```bash
# Build the manifests
kustomize build /Users/wally/projects/kind-flux/app

# Apply to cluster
kustomize build /Users/wally/projects/kind-flux/app | kubectl apply -f -

# Count total external services
kustomize build /Users/wally/projects/kind-flux/app | grep -c "kind: ExternalService"
# Output: 124

# Count total traffic permissions
kustomize build /Users/wally/projects/kind-flux/app | grep -c "kind: MeshTrafficPermission"
# Output: 968
```

### Generate Additional Resources
```bash
# Generate more external services
cd /Users/wally/projects/kind-flux/app
./generate-external-services.sh

# Generate more traffic permissions
./generate-mesh-traffic-permissions.sh

# Generate role-based permissions
./generate-role-based-permissions.sh
```

### Customization
You can modify the scripts to:
- Add more service endpoints
- Change protocols (http, https, tcp, grpc, kafka)
- Modify ports and TLS settings
- Add different service categories
- Create custom role-based access patterns
- Add environment-specific restrictions

## Kong Mesh Traffic Permission Patterns

### 1. Service-to-Service Access
```yaml
spec:
  targetRef:
    kind: MeshSubset
    tags:
      kuma.io/service: external-service-name
  from:
  - targetRef:
      kind: MeshSubset
      tags:
        kuma.io/service: source-service-name
    default:
      action: Allow
```

### 2. Role-Based Access
```yaml
spec:
  targetRef:
    kind: MeshSubset
    tags:
      kuma.io/service: external-service-name
  from:
  - targetRef:
      kind: MeshSubset
      tags:
        role: developer
        env: development
    default:
      action: Allow
```

### 3. Component-Based Access
```yaml
spec:
  targetRef:
    kind: MeshSubset
    tags:
      kuma.io/service: external-service-name
  from:
  - targetRef:
      kind: MeshSubset
      tags:
        component: ci-cd
    default:
      action: Allow
```

### 4. Wildcard Pattern Access
```yaml
spec:
  targetRef:
    kind: MeshSubset
    tags:
      kuma.io/service: "*-external"
  from:
  - targetRef:
      kind: MeshSubset
      tags:
        role: admin
    default:
      action: Allow
```

## Kustomize Features Demonstrated

1. **Resource Composition** - Multiple YAML files combined seamlessly
2. **Scalable Configuration** - Script-based generation for additional services and permissions
3. **Namespace Management** - All services properly namespaced
4. **Build Validation** - Kustomize validates all configurations
5. **Template Generation** - Automated resource creation

## Kong Mesh Configuration

### External Services Include:
- Unique name and service tag
- Protocol specification (http, tcp, grpc, kafka)
- TLS configuration (enabled by default)
- Target address and port (typically 443 for HTTPS)
- Mesh assignment (demo mesh)

### Traffic Permissions Include:
- Source service identification via tags
- Target service identification via tags
- Allow/Deny actions
- Role-based access control
- Environment-based restrictions
- Component-based access patterns

This setup provides a comprehensive example of managing many external services and their corresponding traffic permissions in a Kong mesh environment using Kustomize for scalable configuration management, demonstrating real-world enterprise patterns for service mesh security and access control.
