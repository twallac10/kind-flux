#!/bin/bash

# Kong Mesh Validation Script
# Checks MeshTrafficPermissions for Kong mesh compatibility

echo "🔍 Kong Mesh Validation Check"
echo "=============================="

# Check for wildcard patterns
echo "1. Checking for wildcard patterns in service tags..."
WILDCARDS=$(kustomize build . | grep -E "kuma\.io/service.*[\*\?]" | wc -l)
if [ "$WILDCARDS" -eq 0 ]; then
    echo "   ✅ No wildcard patterns found"
else
    echo "   ❌ Found $WILDCARDS wildcard patterns (not allowed in Kong mesh)"
    kustomize build . | grep -E "kuma\.io/service.*[\*\?]" | head -5
fi

# Check for invalid characters in service tags
echo "2. Checking for invalid characters in service tags..."
INVALID_CHARS=$(kustomize build . | grep "kuma.io/service:" | sed 's/.*kuma.io\/service: *//' | grep -E "[^a-zA-Z0-9._-]" | wc -l)
if [ "$INVALID_CHARS" -eq 0 ]; then
    echo "   ✅ All service tags use valid characters"
else
    echo "   ❌ Found $INVALID_CHARS service tags with invalid characters"
    kustomize build . | grep "kuma.io/service:" | sed 's/.*kuma.io\/service: *//' | grep -E "[^a-zA-Z0-9._-]" | head -5
fi

# Count resources
echo "3. Resource Summary:"
EXTERNAL_SERVICES=$(kustomize build . | grep -c "kind: ExternalService")
TRAFFIC_PERMISSIONS=$(kustomize build . | grep -c "kind: MeshTrafficPermission")
echo "   • ExternalServices: $EXTERNAL_SERVICES"
echo "   • MeshTrafficPermissions: $TRAFFIC_PERMISSIONS"
echo "   • Total: $((EXTERNAL_SERVICES + TRAFFIC_PERMISSIONS))"

# Test kustomize build
echo "4. Testing kustomize build..."
if kustomize build . > /dev/null 2>&1; then
    echo "   ✅ Kustomize build successful"
else
    echo "   ❌ Kustomize build failed"
    exit 1
fi

echo ""
echo "🎉 Validation complete!"
if [ "$WILDCARDS" -eq 0 ] && [ "$INVALID_CHARS" -eq 0 ]; then
    echo "✅ All checks passed - ready for Kong mesh deployment"
    exit 0
else
    echo "❌ Some checks failed - please fix the issues above"
    exit 1
fi
