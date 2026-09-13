#!/bin/bash

# Test Suite for Kyverno MeshPassthrough Policy
# Tests the pp.hqy.io/solution label behavior:
# - httpbin namespace (solution: clms) = MongoDB only
# - test-zcor namespace (solution: zcor) = Any MeshPassthrough allowed

echo "🧪 Starting Kyverno MeshPassthrough Policy Test Suite"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test and check result
run_test() {
    local test_name="$1"
    local test_file="$2"
    local expected_result="$3" # "PASS" or "FAIL"
    
    echo -e "\n${YELLOW}🔍 Testing: ${test_name}${NC}"
    
    if [ "$expected_result" = "PASS" ]; then
        if kubectl apply -f "$test_file" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PASS: Resource was allowed as expected${NC}"
            # Clean up immediately
            kubectl delete -f "$test_file" >/dev/null 2>&1 || true
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL: Resource was blocked but should have been allowed${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        if ! kubectl apply -f "$test_file" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PASS: Resource was blocked as expected${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ FAIL: Resource was allowed but should have been blocked${NC}"
            # Clean up if it was unexpectedly created
            kubectl delete -f "$test_file" >/dev/null 2>&1 || true
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    fi
}

# Ensure test-zcor namespace exists
echo -e "\n🏗️  Setting up test environment..."
kubectl create namespace test-zcor --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
kubectl label namespace test-zcor pp.hqy.io/solution=zcor --overwrite >/dev/null 2>&1

echo "📋 Namespace configurations:"
HTTPBIN_LABEL=$(kubectl get namespace httpbin -o jsonpath='{.metadata.labels.pp\.hqy\.io/solution}' 2>/dev/null || echo "not-found")
ZCOR_LABEL=$(kubectl get namespace test-zcor -o jsonpath='{.metadata.labels.pp\.hqy\.io/solution}' 2>/dev/null || echo "not-found")
echo "- httpbin: $HTTPBIN_LABEL"
echo "- test-zcor: $ZCOR_LABEL"

if [ "$HTTPBIN_LABEL" = "not-found" ] || [ "$ZCOR_LABEL" = "not-found" ]; then
    echo -e "${RED}❌ Error: Required namespace labels not found. Exiting.${NC}"
    exit 1
fi

# Run all tests
echo -e "\n🚀 Running tests..."

# Test 1: MongoDB MeshPassthrough in httpbin (clms) - should PASS
echo "Starting Test 1/7..."
run_test "MongoDB MeshPassthrough in httpbin namespace (clms)" "app/tests/test-mongodb-httpbin.yaml" "PASS"

# Test 2: Non-MongoDB MeshPassthrough in httpbin (clms) - should FAIL
echo "Starting Test 2/7..."
run_test "Non-MongoDB MeshPassthrough in httpbin namespace (clms)" "app/tests/test-nonmongo-httpbin.yaml" "FAIL"

# Test 3: MongoDB MeshPassthrough in test-zcor (zcor) - should PASS
echo "Starting Test 3/7..."
run_test "MongoDB MeshPassthrough in test-zcor namespace (zcor)" "app/tests/test-mongodb-zcor.yaml" "PASS"

# Test 4: Non-MongoDB MeshPassthrough in test-zcor (zcor) - should PASS
echo "Starting Test 4/7..."
run_test "Non-MongoDB MeshPassthrough in test-zcor namespace (zcor)" "app/tests/test-nonmongo-zcor.yaml" "PASS"

# Test 5: Any MeshPassthrough in test-zcor (zcor) - should PASS
echo "Starting Test 5/7..."
run_test "Any domain MeshPassthrough in test-zcor namespace (zcor)" "app/tests/test-any-zcor.yaml" "PASS"

# Test 6: Mesh targetRef in httpbin (clms) - should FAIL
echo "Starting Test 6/7..."
run_test "Mesh targetRef in httpbin namespace (clms)" "app/tests/test-mesh-targetref-httpbin.yaml" "FAIL"

# Test 7: Mesh targetRef in test-zcor (zcor) - should PASS
echo "Starting Test 7/7..."
run_test "Mesh targetRef in test-zcor namespace (zcor)" "app/tests/test-mesh-targetref-zcor.yaml" "PASS"

# Summary
echo -e "\n📊 Test Results Summary"
echo "======================"
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Kyverno policy is working correctly.${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed. Please review the policy configuration.${NC}"
    exit 1
fi
