# Drools/Kogito Platform - YugabyteDB & Teleport Configuration

## Overview

This deployment has been configured to use your existing YugabyteDB deployment and expose all services through Teleport for secure access.

## YugabyteDB Configuration

### Prerequisites
1. **Existing YugabyteDB deployment** in your cluster
2. **Database creation** for KIE Workbench data

### Database Setup

1. **Connect to your YugabyteDB cluster:**
```bash
# Port forward to YugabyteDB (adjust service name as needed)
kubectl port-forward -n yugabyte svc/yb-tserver-service 5433:5433

# Connect using psql
psql -h localhost -p 5433 -U yugabyte -d yugabyte
```

2. **Create the KIE database:**
```sql
-- Create database for Drools/KIE Workbench
CREATE DATABASE kiedb;

-- Create user if needed (optional, can use default yugabyte user)
CREATE USER kieuser WITH PASSWORD 'kiepassword';
GRANT ALL PRIVILEGES ON DATABASE kiedb TO kieuser;

-- Connect to new database
\c kiedb

-- Verify connection
SELECT current_database(), current_user;
```

### Update Configuration

**Update the YugabyteDB service reference in the manifest:**

Edit the `yugabytedb` service in the manifest to point to your actual YugabyteDB service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: yugabytedb
  namespace: drools
spec:
  type: ExternalName
  # Update this line with your actual YugabyteDB service
  externalName: yb-tserver-service.yugabyte.svc.cluster.local
  ports:
  - port: 5433
    targetPort: 5433
    name: ysql
```

**Update the secret with your credentials:**

```bash
# Update YugabyteDB credentials
kubectl create secret generic yugabyte-secret \
  --from-literal=YUGABYTE_USER=$(echo -n "yugabyte" | base64) \
  --from-literal=YUGABYTE_PASSWORD=$(echo -n "yugabyte" | base64) \
  --from-literal=YUGABYTE_DB=$(echo -n "kiedb" | base64) \
  --namespace=drools \
  --dry-run=client -o yaml | kubectl apply -f -
```

Or manually update the secret in the manifest:
```bash
# Encode your credentials
echo -n "your_username" | base64
echo -n "your_password" | base64
echo -n "kiedb" | base64
```

## Teleport Services Configuration

All services are now configured with Teleport annotations for secure external access:

### Service Endpoints

| Service | Teleport Name | Public Address | Purpose |
|---------|---------------|----------------|---------|
| KIE Workbench | `drools-workbench` | `workbench.drools.yourdomain.com` | Business rules authoring GUI |
| KIE Server | `drools-kie-server` | `kie-server.drools.yourdomain.com` | Rules execution API |
| Kogito Decision API | `drools-kogito-decisions` | `kogito.drools.yourdomain.com` | Cloud-native decision API |
| API Gateway | `drools-api-gateway` | `api.drools.yourdomain.com` | Unified web interface |
| Kogito Jobs | `drools-kogito-jobs` | `jobs.drools.yourdomain.com` | Async job processing |
| Data Index | `drools-kogito-data-index` | `monitoring.drools.yourdomain.com` | Monitoring & analytics |
| Rules Service | `drools-rules-service` | `rules.drools.yourdomain.com` | Embeddable rules service |

### Teleport Configuration Steps

1. **Update domain names** in the manifest:
```bash
# Replace 'yourdomain.com' with your actual domain
sed -i 's/yourdomain.com/your-actual-domain.com/g' manifests/k8s-rules.engine.yaml
```

2. **Configure Teleport Application Access:**

Create a Teleport role for Drools access:
```yaml
# teleport-drools-role.yaml
kind: role
version: v5
metadata:
  name: drools-access
spec:
  allow:
    app_labels:
      'teleport.dev/app': ['drools-*']
    logins: ['root']
  options:
    max_session_ttl: 8h
```

Apply the role:
```bash
tctl create teleport-drools-role.yaml
```

3. **Create Teleport user or update existing user:**
```bash
# Add the role to a user
tctl users update your-username --set-roles=drools-access,existing-roles
```

### Service Access Through Teleport

Once Teleport is configured, access services via:

```bash
# List available applications
tsh apps ls

# Login to specific service
tsh apps login drools-workbench
tsh apps login drools-kogito-decisions
tsh apps login drools-api-gateway

# Access via browser
tsh apps login drools-workbench && open https://workbench.drools.yourdomain.com
```

## Deployment Instructions

### 1. Prepare Environment
```bash
# Ensure YugabyteDB is running
kubectl get pods -n yugabyte

# Verify YugabyteDB service endpoint
kubectl get svc -n yugabyte | grep tserver
```

### 2. Update Configuration
```bash
# Update YugabyteDB service reference (edit the manifest)
# Update domain names for Teleport
# Update database credentials if needed
```

### 3. Deploy Platform
```bash
# Deploy Drools/Kogito platform
kubectl apply -f manifests/k8s-rules.engine.yaml

# Verify deployment
./validate-drools-deployment.sh
```

### 4. Configure Database
```bash
# Create database in YugabyteDB (see Database Setup above)
```

### 5. Test Access
```bash
# Test internal connectivity
kubectl port-forward -n drools svc/drools-api-gateway 8080:8080

# Access KIE Workbench
curl -f http://localhost:8080/business-central/

# Test via Teleport (after Teleport configuration)
tsh apps login drools-workbench
```

## Configuration Customization

### YugabyteDB Connection Tuning

For production environments, you may want to tune the database connection:

```yaml
# In kie-workbench-config ConfigMap
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.max-lifetime=1800000
```

### Teleport Labels and RBAC

Customize Teleport labels for fine-grained access control:

```yaml
# Example: Environment-specific access
teleport.dev/labels: "environment=production,team=platform,sensitivity=high"

# Example: Role-based access
teleport.dev/labels: "environment=production,role=rules-author"
```

### High Availability

For production deployment:

1. **YugabyteDB**: Ensure proper RF (replication factor) and node distribution
2. **Services**: Scale critical components:
```bash
kubectl scale deployment kie-server -n drools --replicas=3
kubectl scale deployment kogito-decision-service -n drools --replicas=3
kubectl scale deployment api-gateway -n drools --replicas=2
```

## Monitoring and Troubleshooting

### Health Checks

All services provide health endpoints accessible through Teleport:

```bash
# Via port-forward for testing
kubectl port-forward -n drools svc/drools-api-gateway 8080:8080

# Health endpoints
curl http://localhost:8080/health                    # API Gateway
curl http://localhost:8080/decisions/q/health        # Kogito Decision Service
curl http://localhost:8080/kie-server/services/rest/server # KIE Server
```

### Database Connection Issues

Common troubleshooting steps:

```bash
# Check YugabyteDB connectivity
kubectl exec -n drools deployment/kie-workbench -- \
  psql -h yugabytedb.drools.svc.cluster.local -p 5433 -U yugabyte -d kiedb -c "SELECT 1"

# Check service DNS resolution
kubectl exec -n drools deployment/kie-workbench -- nslookup yugabytedb.drools.svc.cluster.local

# Check logs for database errors
kubectl logs -n drools deployment/kie-workbench | grep -i database
```

### Service Discovery Issues

```bash
# Verify all services are running
kubectl get pods -n drools -l 'teleport.dev/app'

# Check service endpoints
kubectl get svc -n drools

# Test internal service communication
kubectl exec -n drools deployment/api-gateway -- curl -f http://kie-workbench:8080/business-central/
```

## Security Considerations

1. **Database Security**:
   - Use strong passwords for YugabyteDB
   - Enable SSL/TLS for database connections
   - Network policies for database access

2. **Teleport Security**:
   - Implement proper RBAC roles
   - Use certificate-based authentication
   - Regular audit of access logs

3. **Service Security**:
   - Change default KIE credentials
   - Implement proper authentication in KIE Workbench
   - Network policies between services

## Migration Notes

### From PostgreSQL to YugabyteDB

The migration maintains PostgreSQL compatibility:
- **Driver**: Still uses PostgreSQL JDBC driver
- **Dialect**: Hibernate PostgreSQL dialect works with YugabyteDB
- **Port**: Changed from 5432 to 5433 (YugabyteDB default)
- **Performance**: YugabyteDB provides better scalability and availability

### Benefits of YugabyteDB

- **Horizontal scaling**: Auto-sharding and replication
- **High availability**: Built-in fault tolerance
- **PostgreSQL compatibility**: No application changes needed
- **Multi-region deployment**: Global data distribution
- **Backup and restore**: Built-in point-in-time recovery

This configuration provides a production-ready, scalable Drools/Kogito platform with secure Teleport access and enterprise-grade YugabyteDB backend.