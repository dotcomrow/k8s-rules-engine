#!/bin/bash

# =========================
# Drools Platform Validation Script
# =========================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="${NAMESPACE:-drools}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
YUGABYTE_NAMESPACE="${YUGABYTE_NAMESPACE:-yugabyte}"
YUGABYTE_YSQL_SVC="${YUGABYTE_YSQL_SVC:-yb-ysql}"
YUGABYTE_YSQL_PORT="${YUGABYTE_YSQL_PORT:-5433}"

YUGABYTE_SVC_OK="false"
YUGABYTE_CONN_OK="false"

echo -e "${BLUE}================================"
echo -e "Drools Platform Validation"
echo -e "================================${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

# Check namespace
echo -e "\n${BLUE}1. Checking namespace...${NC}"
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' exists${NC}"
else
    echo -e "${RED}✗ Namespace '$NAMESPACE' not found${NC}"
    echo -e "${YELLOW}Create namespace: kubectl create namespace $NAMESPACE${NC}"
    exit 1
fi

# Check initialization jobs
echo -e "\n${BLUE}2. Checking Vault and YugabyteDB initialization...${NC}"

# Check Vault root token copy job
if kubectl get job copy-drools-vault-root-token -n "$VAULT_NAMESPACE" &>/dev/null; then
    JOB_STATUS=$(kubectl get job copy-drools-vault-root-token -n "$VAULT_NAMESPACE" -o jsonpath='{.status.succeeded}')
    if [ "${JOB_STATUS:-0}" -ge 1 ]; then
        echo -e "${GREEN}✓ Vault root token copy job completed${NC}"
    else
        echo -e "${YELLOW}⚠ Vault root token copy job not completed${NC}"
    fi
else
    echo -e "${RED}✗ Vault root token copy job not found${NC}"
fi

# Check YugabyteDB configuration job
if kubectl get job drools-yugabyte-config -n "$VAULT_NAMESPACE" &>/dev/null; then
    JOB_STATUS=$(kubectl get job drools-yugabyte-config -n "$VAULT_NAMESPACE" -o jsonpath='{.status.succeeded}')
    if [ "${JOB_STATUS:-0}" -ge 1 ]; then
        echo -e "${GREEN}✓ YugabyteDB configuration job completed${NC}"
    else
        echo -e "${YELLOW}⚠ YugabyteDB configuration job running or failed${NC}"
        echo -e "${YELLOW}  Check job logs: kubectl logs -n $VAULT_NAMESPACE job/drools-yugabyte-config${NC}"
    fi
else
    echo -e "${RED}✗ YugabyteDB configuration job not found${NC}"
fi

# Check YugabyteDB connectivity
echo -e "\n${BLUE}3. Checking YugabyteDB database connectivity...${NC}"
YUGABYTE_YSQL_HOST="${YUGABYTE_YSQL_SVC}.${YUGABYTE_NAMESPACE}.svc.cluster.local"
if kubectl get service "$YUGABYTE_YSQL_SVC" -n "$YUGABYTE_NAMESPACE" &>/dev/null; then
    YUGABYTE_SVC_OK="true"
else
    echo -e "${RED}✗ YugabyteDB service not found: $YUGABYTE_YSQL_SVC (namespace: $YUGABYTE_NAMESPACE)${NC}"
fi

DB_TEST_TARGET=""
DB_TEST_CONTAINER=""
if kubectl get deployment kie-workbench -n "$NAMESPACE" &>/dev/null; then
    DB_TEST_TARGET="deployment/kie-workbench"
    DB_TEST_CONTAINER="kie-workbench"
elif kubectl get statefulset kie-server -n "$NAMESPACE" &>/dev/null; then
    DB_TEST_TARGET="pod/kie-server-0"
    DB_TEST_CONTAINER="kie-server"
elif kubectl get deployment kie-server -n "$NAMESPACE" &>/dev/null; then
    DB_TEST_TARGET="deployment/kie-server"
    DB_TEST_CONTAINER="kie-server"
fi

if [ -n "$DB_TEST_TARGET" ]; then
    # Use bash /dev/tcp so we don't depend on netcat being installed in the image.
    if kubectl exec -n "$NAMESPACE" "$DB_TEST_TARGET" -c "$DB_TEST_CONTAINER" -- bash -c "timeout 3 bash -c '</dev/tcp/${YUGABYTE_YSQL_HOST}/${YUGABYTE_YSQL_PORT}'" &>/dev/null; then
        YUGABYTE_CONN_OK="true"
        echo -e "${GREEN}✓ YugabyteDB connectivity successful (${YUGABYTE_YSQL_HOST}:${YUGABYTE_YSQL_PORT})${NC}"
    else
        echo -e "${YELLOW}⚠ YugabyteDB connectivity test failed (${YUGABYTE_YSQL_HOST}:${YUGABYTE_YSQL_PORT})${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipping YugabyteDB connectivity check (no Workbench/KIE Server workload found yet)${NC}"
fi

# Check KIE Workbench
echo -e "\n${BLUE}4. Checking KIE Workbench...${NC}"
KIE_WB_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app=kie-workbench -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")

if [ "$KIE_WB_STATUS" = "Running" ]; then
    echo -e "${GREEN}✓ KIE Workbench is running${NC}"
    
    # Check readiness
    READY=$(kubectl get pods -n "$NAMESPACE" -l app=kie-workbench -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [ "$READY" = "true" ]; then
        echo -e "${GREEN}✓ KIE Workbench is ready${NC}"
    else
        echo -e "${YELLOW}⚠ KIE Workbench not ready${NC}"
    fi
else
    echo -e "${RED}✗ KIE Workbench not running (Status: $KIE_WB_STATUS)${NC}"
fi

# Check KIE Server
echo -e "\n${BLUE}5. Checking KIE Server...${NC}"
KIE_SERVER_KIND="deployment"
if kubectl get statefulset kie-server -n "$NAMESPACE" >/dev/null 2>&1; then
    KIE_SERVER_KIND="statefulset"
    KIE_SERVER_REPLICAS=$(kubectl get statefulset kie-server -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    KIE_SERVER_DESIRED=$(kubectl get statefulset kie-server -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
else
    KIE_SERVER_REPLICAS=$(kubectl get deployment kie-server -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    KIE_SERVER_DESIRED=$(kubectl get deployment kie-server -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
fi

if [ "$KIE_SERVER_REPLICAS" = "$KIE_SERVER_DESIRED" ] && [ "$KIE_SERVER_REPLICAS" != "0" ]; then
    echo -e "${GREEN}✓ KIE Server running ($KIE_SERVER_REPLICAS/$KIE_SERVER_DESIRED replicas, $KIE_SERVER_KIND)${NC}"
else
    echo -e "${YELLOW}⚠ KIE Server not fully ready ($KIE_SERVER_REPLICAS/$KIE_SERVER_DESIRED replicas, $KIE_SERVER_KIND)${NC}"
fi

# Test Workbench connectivity
echo -e "\n${BLUE}6. Testing Workbench connectivity...${NC}"
echo -e "${YELLOW}Setting up port forward for KIE Workbench...${NC}"
kubectl port-forward -n "$NAMESPACE" svc/kie-workbench 8080:8080 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 5
if curl -s -f http://localhost:8080/business-central/ &>/dev/null; then
    echo -e "${GREEN}✓ KIE Workbench reachable${NC}"
else
    echo -e "${YELLOW}⚠ KIE Workbench not reachable (may still be starting)${NC}"
fi
kill $PORT_FORWARD_PID &>/dev/null || true
wait $PORT_FORWARD_PID 2>/dev/null || true

# Test KIE Server API
echo -e "\n${BLUE}7. Testing KIE Server API connectivity...${NC}"
echo -e "${YELLOW}Setting up port forward for KIE Server...${NC}"
kubectl port-forward -n "$NAMESPACE" svc/kie-server 8081:8080 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
sleep 5
if curl -s -f http://localhost:8081/kie-server/services/rest/server &>/dev/null; then
    echo -e "${GREEN}✓ KIE Server API reachable${NC}"
else
    echo -e "${YELLOW}⚠ KIE Server API not reachable (may still be starting)${NC}"
fi
kill $PORT_FORWARD_PID &>/dev/null || true
wait $PORT_FORWARD_PID 2>/dev/null || true

# Show resource usage
echo -e "\n${BLUE}8. Resource usage...${NC}"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo -e "${YELLOW}Metrics not available (install metrics-server)${NC}"

# Show all pods status
echo -e "\n${BLUE}9. All pods status:${NC}"
kubectl get pods -n "$NAMESPACE" -o wide

echo -e "\n${BLUE}================================"
echo -e "Validation Summary"
echo -e "================================${NC}"

echo -e "\n${YELLOW}Service Status:${NC}"
YUGABYTE_STATUS="${RED}✗ Not configured${NC}"
if [ "$YUGABYTE_SVC_OK" = "true" ]; then
    YUGABYTE_STATUS="${YELLOW}⚠ Service present${NC}"
fi
if [ "$YUGABYTE_CONN_OK" = "true" ]; then
    YUGABYTE_STATUS="${GREEN}✓ Reachable${NC}"
fi
echo -e "• YugabyteDB: $YUGABYTE_STATUS"
echo -e "• KIE Workbench: $([ "$KIE_WB_STATUS" = "Running" ] && echo -e "${GREEN}✓ Running${NC}" || echo -e "${RED}✗ $KIE_WB_STATUS${NC}")"
echo -e "• KIE Server: $([ "$KIE_SERVER_REPLICAS" = "$KIE_SERVER_DESIRED" ] && [ "$KIE_SERVER_REPLICAS" != "0" ] && echo -e "${GREEN}✓ Ready${NC}" || echo -e "${YELLOW}⚠ $KIE_SERVER_REPLICAS/$KIE_SERVER_DESIRED${NC}")"

echo -e "\n${YELLOW}Access URLs (with port-forward):${NC}"
echo -e "• Rules Authoring: http://localhost:8080/business-central/ (admin/admin)"
echo -e "• KIE Server API: http://localhost:8081/kie-server/services/rest/server"

echo -e "\n${YELLOW}Vault Integration:${NC}"
echo -e "• Database credentials: Dynamic (24h rotation)"
echo -e "• Admin credentials: Vault-managed"  
echo -e "• KIE Server credentials: Vault-managed"
echo -e "• Initialization job: drools-yugabyte-config"

echo -e "\n${YELLOW}Teleport Services Configured:${NC}"
echo -e "• drools-workbench (KIE Workbench GUI)"
echo -e "• drools-kie-server (Rules Execution API)"
echo -e "• drools-rules-service (Embedded Service)"

echo -e "\n${YELLOW}Quick Commands:${NC}"
echo -e "• Port forward (Workbench): kubectl port-forward -n $NAMESPACE svc/kie-workbench 8080:8080"
echo -e "• Port forward (KIE Server): kubectl port-forward -n $NAMESPACE svc/kie-server 8081:8080"
echo -e "• Check logs: kubectl logs -n $NAMESPACE deployment/kie-workbench -f"
if [ "$KIE_SERVER_KIND" = "statefulset" ]; then
    echo -e "• Scale services: kubectl scale -n $NAMESPACE statefulset/kie-server --replicas=3"
else
    echo -e "• Scale services: kubectl scale -n $NAMESPACE deployment/kie-server --replicas=3"
fi

echo -e "\n${YELLOW}Troubleshooting:${NC}"
if [ "$KIE_WB_STATUS" != "Running" ] || [ "$YUGABYTE_CONN_OK" != "true" ]; then
    echo -e "• Check database connectivity and resources"
    echo -e "• Verify persistent volume claims: kubectl get pvc -n $NAMESPACE"
    echo -e "• Check pod events: kubectl describe pods -n $NAMESPACE"
fi

if [ "$KIE_SERVER_REPLICAS" != "$KIE_SERVER_DESIRED" ]; then
    echo -e "• Check resource limits and node capacity"
    echo -e "• Review service logs for startup issues"
fi

echo -e "\n${GREEN}Validation complete!${NC}"
