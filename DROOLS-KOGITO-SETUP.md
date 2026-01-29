# Drools/Kogito Rules Engine Platform

## Overview

This deployment provides a complete Drools/Kogito business rules management and execution platform with:

### 🏗️ **Architecture Components**

1. **KIE Workbench** - Web-based authoring environment for business rules
2. **KIE Server** - Production runtime for rule execution (embeddable)
3. **Kogito Decision Service** - Cloud-native microservice for decisions
4. **PostgreSQL** - Database for storing projects and configurations
5. **API Gateway** - NGINX reverse proxy with CORS support
6. **Kogito Jobs Service** - Async job processing
7. **Kogito Data Index** - Decision execution monitoring and indexing

### 🎯 **Use Cases Supported**

- **Web Authoring**: Business users create rules in KIE Workbench
- **Hosted Service**: REST API for decision execution via Kogito
- **Embeddable Library**: KIE Server for application integration
- **Decision Management**: Full lifecycle from authoring to production

## Quick Start

### 1. Deploy the Platform
```bash
kubectl apply -f manifests/k8s-rules.engine.yaml
```

### 2. Wait for Services to Start
```bash
# Check deployment status
kubectl get pods -n drools -w

# All pods should be Running
kubectl get pods -n drools
```

### 3. Access the Services

#### Port Forward for Local Development
```bash
# KIE Workbench (Business Rules Authoring)
kubectl port-forward -n drools svc/api-gateway 8080:8080

# Access at: http://localhost:8080/business-central/
# Login: admin/admin
```

#### Service Endpoints
- **Rules Authoring GUI**: `/business-central/` 
- **KIE Server API**: `/kie-server/services/rest/server`
- **Kogito Decision API**: `/decisions/`
- **API Documentation**: `/api/docs`
- **Health Check**: `/health`

## Service Details

### 🎨 KIE Workbench - Rules Authoring
**Purpose**: Web-based IDE for creating business rules, decision tables, and guided rules

**Features**:
- Visual rule authoring
- Decision table editor
- Rule templates
- Asset repository
- Project management
- Maven integration

**Default Credentials**: `admin/admin`

**URLs**:
- Main Interface: `/business-central/`
- Asset Library: `/business-central/spaces/MySpace`
- Project Import: `/business-central/spaces/MySpace/projects`

### ⚙️ KIE Server - Production Runtime
**Purpose**: Embeddable execution server for production rule execution

**Features**:
- REST API for rule execution
- Container management
- Rule deployment from Workbench
- Scalable execution
- Monitoring and metrics

**API Examples**:
```bash
# Check server info
curl http://localhost:8080/kie-server/services/rest/server

# List containers
curl -u kieserver:kieserver1! http://localhost:8080/kie-server/services/rest/server/containers

# Execute rules (example)
curl -X POST \
  -H "Content-Type: application/json" \
  -u kieserver:kieserver1! \
  http://localhost:8080/kie-server/services/rest/server/containers/instances/my-rules \
  -d '{"lookup": "default-stateless-ksession", "commands": [{"insert": {"object": {"com.example.Person": {"name": "john", "age": 25}}}}, {"fire-all-rules": {}}, {"get-objects": {"out-identifier": "objects"}}]}'
```

### ☁️ Kogito Decision Service - Cloud Native
**Purpose**: Modern Quarkus-based microservice for decision execution

**Features**:
- Fast startup (< 1 second)
- Low memory footprint
- Native compilation support
- OpenAPI/Swagger documentation
- Cloud-native patterns

**API Examples**:
```bash
# Health check
curl http://localhost:8080/decisions/q/health

# OpenAPI spec
curl http://localhost:8080/decisions/q/openapi

# Execute decision (depends on your deployed model)
curl -X POST \
  -H "Content-Type: application/json" \
  http://localhost:8080/decisions/my-decision \
  -d '{"input": "value"}'
```

### 🗄️ PostgreSQL Database
**Purpose**: Persistent storage for KIE Workbench projects and configuration

**Connection Details**:
- Host: `postgres.drools.svc.cluster.local`
- Port: `5432`
- Database: `kiedb`
- Username: `postgres`
- Password: `password`

## Development Workflow

### 1. Create Rules in KIE Workbench
1. Access KIE Workbench at `/business-central/`
2. Login with `admin/admin`
3. Create new space and project
4. Add rule assets (DRL files, decision tables, etc.)
5. Build and deploy project

### 2. Deploy to KIE Server
1. In Workbench, go to "Deploy" → "Execution Servers"
2. Add KIE Server endpoint: `http://kie-server.drools.svc.cluster.local:8080/kie-server/services/rest/server`
3. Deploy container with your rules

### 3. Execute Rules via API
```bash
# Via KIE Server (traditional)
curl -u kieserver:kieserver1! \
  -H "Content-Type: application/json" \
  -X POST http://localhost:8080/kie-server/services/rest/server/containers/instances/my-container \
  -d '{"your": "payload"}'

# Via Kogito (cloud-native)
curl -H "Content-Type: application/json" \
  -X POST http://localhost:8080/decisions/my-decision \
  -d '{"your": "payload"}'
```

## Integration Patterns

### Embeddable Library Pattern
Use KIE Server for applications that need embedded rule execution:

```java
// Java application integration
KieServicesClient kieServicesClient = KieServicesFactory.newKieServicesClient(configuration);
RuleServicesClient ruleClient = kieServicesClient.getServicesClient(RuleServicesClient.class);
```

### Microservice Pattern
Use Kogito Decision Service for cloud-native applications:

```javascript
// REST API integration
const response = await fetch('/decisions/my-rules', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify(inputData)
});
```

### Batch Processing Pattern
Use Kogito Jobs Service for scheduled rule execution:

```bash
# Schedule job
curl -X POST http://localhost:8080/jobs \
  -H "Content-Type: application/json" \
  -d '{"id": "my-job", "expirationTime": "2024-12-31T23:59:59Z", "callbackEndpoint": "/my-callback"}'
```

## Configuration

### Database Configuration
The PostgreSQL database stores:
- Project metadata
- Rule artifacts
- User preferences
- Deployment configurations

### Security Configuration
Default credentials (change in production):
- KIE Workbench: `admin/admin`
- KIE Server: `kieserver/kieserver1!`

### Scaling Configuration
```bash
# Scale KIE Server for high throughput
kubectl scale deployment kie-server -n drools --replicas=5

# Scale Kogito Decision Service
kubectl scale deployment kogito-decision-service -n drools --replicas=3

# Scale API Gateway
kubectl scale deployment api-gateway -n drools --replicas=3
```

## Monitoring and Troubleshooting

### Check Service Health
```bash
# All services
kubectl get pods -n drools

# Specific service logs
kubectl logs -n drools deployment/kie-workbench -f
kubectl logs -n drools deployment/kie-server -f
kubectl logs -n drools deployment/kogito-decision-service -f
```

### Performance Monitoring
```bash
# Resource usage
kubectl top pods -n drools

# Service metrics (if available)
curl http://localhost:8080/kie-server/services/rest/server/info
curl http://localhost:8080/decisions/q/metrics
```

### Common Issues

**Issue**: KIE Workbench won't start
**Solution**: Check database connectivity and memory limits

**Issue**: Rules not executing
**Solution**: Verify container deployment in KIE Server

**Issue**: Kogito service 404
**Solution**: Ensure decision models are deployed

**Note**: We no longer inject CSS into the Kogito Management Console via the proxy. If the
UI appears unstyled, fix it at the source (custom image/theme) rather than adding a proxy
sub_filter hack.

## Production Considerations

### Security
- Change default passwords
- Enable HTTPS/TLS
- Configure authentication (LDAP/OAuth)
- Network policies for pod-to-pod communication

### Performance
- Increase memory for KIE Workbench (3Gi+ recommended)
- Scale KIE Server replicas based on load
- Use persistent volumes for database
- Configure connection pooling

### Backup
- Database backups (PostgreSQL)
- Git repository backups (rule projects)
- Container registry backups

### Networking
```bash
# Expose via LoadBalancer (cloud environments)
kubectl patch svc rules-engine-gui -n drools -p '{"spec": {"type": "LoadBalancer"}}'

# Or via Ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: drools-ingress
  namespace: drools
spec:
  rules:
  - host: rules.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rules-engine-gui
            port:
              number: 8080
EOF
```

## API Reference

### KIE Server REST API
- Base URL: `/kie-server/services/rest`
- Documentation: [KIE Server REST API](https://docs.jboss.org/drools/release/latest/drools-docs/html_single/#_kie_server_rest_api)

### Kogito Decision API
- Base URL: `/decisions`
- Documentation: `/api/docs` (Swagger UI)
- OpenAPI Spec: `/api/openapi`

## Example Rule Files

### Simple DRL Rule
```drl
package com.example.rules

import com.example.model.Person
import com.example.model.Discount

rule "Senior Discount"
when
    $person : Person(age >= 65)
then
    Discount discount = new Discount();
    discount.setType("SENIOR");
    discount.setPercentage(0.10);
    insert(discount);
end
```

### Decision Table (Excel format)
| Condition | Condition | Action |
|-----------|-----------|---------|
| Customer Age | Order Amount | Discount % |
| >= 65 | >= 100 | 15 |
| >= 65 | < 100 | 10 |
| < 65 | >= 500 | 5 |

## GitHub Packages Maven Flow

### Runtime credentials (Vault)
- Token: `secret/k8s-rules-engine-github-packages-token`
- Username: `secret/k8s-rules-engine-github-packages-username`
- Both secrets use the key `value`.

### Repo URL
`https://maven.pkg.github.com/dotcomrow/rules-packages`

### Naming scheme
- `groupId`: `systems.suncoast.rules.<domain>`
- `artifactId`: `<app>-rules`
- `containerId`: `<domain>-<app>`

### App-of-apps scaffolding
See `scaffolding/rules-apps` for the ApplicationSet and per-app registration Job template.

## Support and Resources

- **Drools Documentation**: https://docs.drools.org/
- **Kogito Documentation**: https://docs.kogito.kie.org/
- **KIE Community**: https://www.drools.org/community/
- **GitHub Issues**: Report issues with your deployment setup
