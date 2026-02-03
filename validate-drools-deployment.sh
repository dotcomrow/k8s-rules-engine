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

NAMESPACE="drools"

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
if kubectl get job copy-drools-vault-root-token -n vault &>/dev/null; then
    JOB_STATUS=$(kubectl get job copy-drools-vault-root-token -n vault -o jsonpath='{.status.succeeded}')
    if [ "${JOB_STATUS:-0}" -ge 1 ]; then
        echo -e "${GREEN}✓ Vault root token copy job completed${NC}"
    else
        echo -e "${YELLOW}⚠ Vault root token copy job not completed${NC}"
    fi
else
    echo -e "${RED}✗ Vault root token copy job not found${NC}"
fi

# Check YugabyteDB configuration job
if kubectl get job drools-yugabyte-config -n vault &>/dev/null; then
    JOB_STATUS=$(kubectl get job drools-yugabyte-config -n vault -o jsonpath='{.status.succeeded}')
    if [ "${JOB_STATUS:-0}" -ge 1 ]; then
        echo -e "${GREEN}✓ YugabyteDB configuration job completed${NC}"
    else
        echo -e "${YELLOW}⚠ YugabyteDB configuration job running or failed${NC}"
        echo -e "${YELLOW}  Check job logs: kubectl logs -n vault job/drools-yugabyte-config${NC}"
    fi
else
    echo -e "${RED}✗ YugabyteDB configuration job not found${NC}"
fi

# Check YugabyteDB connectivity
echo -e "\n${BLUE}3. Checking YugabyteDB database connectivity...${NC}"
if kubectl exec -n drools deployment/kie-workbench -- nc -z yb-tserver-service.yugabyte.svc.cluster.local 5433 &>/dev/null; then
    echo -e "${GREEN}✓ YugabyteDB connectivity successful${NC}"
else
    echo -e "${YELLOW}⚠ YugabyteDB connectivity test failed (may be normal if pods not ready)${NC}"
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
KIE_SERVER_REPLICAS=$(kubectl get deployment kie-server -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
KIE_SERVER_DESIRED=$(kubectl get deployment kie-server -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

if [ "$KIE_SERVER_REPLICAS" = "$KIE_SERVER_DESIRED" ] && [ "$KIE_SERVER_REPLICAS" != "0" ]; then
    echo -e "${GREEN}✓ KIE Server running ($KIE_SERVER_REPLICAS/$KIE_SERVER_DESIRED replicas)${NC}"
else
    echo -e "${YELLOW}⚠ KIE Server not fully ready ($KIE_SERVER_REPLICAS/$KIE_SERVER_DESIRED replicas)${NC}"
fi

# Test Workbench connectivity
echo -e "\n${BLUE}6. Testing Workbench connectivity...${NC}"
echo -e "${YELLOW}Setting up port forward for KIE Workbench...${NC}"
kubectl port-forward -n "$NAMESPACE" svc/kie-workbench 8080:8080 &
PORT_FORWARD_PID=$!
sleep 5
if curl -s -f http://localhost:8080/business-central/ &>/dev/null; then
    echo -e "${GREEN}✓ KIE Workbench reachable${NC}"
else
    echo -e "${YELLOW}⚠ KIE Workbench not reachable (may still be starting)${NC}"
fi
kill $PORT_FORWARD_PID &>/dev/null

# Test KIE Server API
echo -e "\n${BLUE}7. Testing KIE Server API connectivity...${NC}"
echo -e "${YELLOW}Setting up port forward for KIE Server...${NC}"
kubectl port-forward -n "$NAMESPACE" svc/kie-server 8081:8080 &
PORT_FORWARD_PID=$!
sleep 5
if curl -s -f http://localhost:8081/kie-server/services/rest/server &>/dev/null; then
    echo -e "${GREEN}✓ KIE Server API reachable${NC}"
else
    echo -e "${YELLOW}⚠ KIE Server API not reachable (may still be starting)${NC}"
fi
kill $PORT_FORWARD_PID &>/dev/null

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
echo -e "• YugabyteDB: $(kubectl get service yugabytedb -n "$NAMESPACE" &>/dev/null && echo -e "${GREEN}✓ Configured${NC}" || echo -e "${RED}✗ Not configured${NC}")"
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
echo -e "• Scale services: kubectl scale -n $NAMESPACE deployment/kie-server --replicas=3"

echo -e "\n${YELLOW}Troubleshooting:${NC}"
if [ "$KIE_WB_STATUS" != "Running" ] || [ "$POSTGRES_STATUS" != "Running" ]; then
    echo -e "• Check database connectivity and resources"
    echo -e "• Verify persistent volume claims: kubectl get pvc -n $NAMESPACE"
    echo -e "• Check pod events: kubectl describe pods -n $NAMESPACE"
fi

if [ "$KIE_SERVER_REPLICAS" != "$KIE_SERVER_DESIRED" ]; then
    echo -e "• Check resource limits and node capacity"
    echo -e "• Review service logs for startup issues"
fi

echo -e "\n${GREEN}Validation complete!${NC}"
