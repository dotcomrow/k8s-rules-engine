# Kogito Decision Service Deployment Guide

## Current Status

The `kogito-decision-service` is currently running as a **mock service** using nginx to provide the required API endpoints. This ensures your Drools platform can deploy successfully while you prepare your actual decision service.

## Mock Service Endpoints

The current mock provides:
- `GET /q/health/ready` - Health check (ready)
- `GET /q/health/live` - Health check (live) 
- `GET /q/swagger-ui` - API documentation placeholder
- `GET /q/openapi` - OpenAPI spec placeholder
- `GET /` - Service status

## Replacing with Production Decision Service

### Option 1: Deploy Your Custom Kogito Decision Service

1. **Build your Kogito application:**
   ```bash
   # Create a new Kogito project
   mvn archetype:generate \
     -DarchetypeGroupId=org.kie.kogito \
     -DarchetypeArtifactId=kogito-quarkus-archetype \
     -DgroupId=com.company \
     -DartifactId=decision-service
   
   # Add your DMN/DRL files to src/main/resources
   # Build the application
   mvn clean package -Pnative
   
   # Create Docker image
   docker build -f src/main/docker/Dockerfile.native -t your-registry/decision-service:1.0 .
   ```

2. **Update the manifest:**
   ```yaml
   - name: kogito-decision-service
     image: your-registry/decision-service:1.0  # Replace mock
     ports:
     - containerPort: 8080
     env:
     - name: QUARKUS_HTTP_PORT
       value: "8080"
     - name: QUARKUS_HTTP_HOST
       value: "0.0.0.0"
   ```

### Option 2: Use Red Hat PAM Kogito Images

If you have Red Hat subscriptions:

```yaml
- name: kogito-decision-service  
  image: registry.redhat.io/rhpam-7/rhpam-kogito-runtime-jvm-rhel8:latest
  env:
  - name: KOGITO_SERVICE_URL
    value: "http://kogito-decision-service.drools.svc.cluster.local:8080"
```

### Option 3: Deploy Kogito Example Decision Services

Use community examples for testing:

```bash
# Clone Kogito examples
git clone https://github.com/kiegroup/kogito-examples
cd kogito-examples/dmn-quarkus-example

# Build and deploy
mvn clean package -Pnative
docker build -f src/main/docker/Dockerfile.native -t kogito-dmn-example .

# Update manifest
image: kogito-dmn-example:latest
```

## Production Considerations

### 1. DMN Decision Models
Place your `.dmn` files in `src/main/resources` of your Kogito project.

### 2. DRL Rules Files  
Place your `.drl` files in `src/main/resources` of your Kogito project.

### 3. Environment Variables
Configure these for production:
```yaml
env:
- name: KOGITO_JOBS_SERVICE_URL
  value: "http://kogito-jobs-service.drools.svc.cluster.local:8080"
- name: KOGITO_DATAINDEX_HTTP_URL  
  value: "http://kogito-data-index.drools.svc.cluster.local:8080"
- name: QUARKUS_LOG_LEVEL
  value: "INFO"
```

### 4. Resource Limits
Adjust based on your decision complexity:
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"  
  limits:
    memory: "1Gi"
    cpu: "800m"
```

## Integration with KIE Server

The decision service integrates with your existing KIE Server through the API Gateway:
- **KIE Server**: Traditional WildFly-based rules execution
- **Kogito Decision**: Cloud-native Quarkus-based decisions
- **API Gateway**: Routes requests to appropriate service

## Next Steps

1. **Immediate**: The platform will deploy successfully with the mock service
2. **Short-term**: Replace mock with your actual Kogito decision service image  
3. **Long-term**: Develop comprehensive DMN/DRL models for your business rules

## Troubleshooting

If your decision service fails:
1. Check logs: `kubectl logs -n drools deployment/kogito-decision-service`
2. Verify health endpoints respond correctly
3. Ensure your JAR file is properly built and included in the image
4. Check resource limits and adjust if needed

The mock service ensures your platform remains operational while you develop your decision services.