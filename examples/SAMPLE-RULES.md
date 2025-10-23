# Sample Drools Rules Examples

This directory contains example rules and decision models to help you get started with the Drools/Kogito platform.

## Quick Start Examples

### 1. Simple Business Rule (DRL)

Create this rule in KIE Workbench under `src/main/resources/rules/`:

**File: `PersonDiscountRules.drl`**
```drl
package com.example.rules.discount

import com.example.model.Person
import com.example.model.Discount

rule "Senior Citizen Discount"
    when
        $person : Person(age >= 65)
    then
        Discount discount = new Discount("SENIOR", 15.0);
        discount.setApplicableToCustomer($person.getId());
        insert(discount);
        System.out.println("Applied senior discount to: " + $person.getName());
end

rule "Student Discount"
    when
        $person : Person(studentId != null, age < 30)
    then
        Discount discount = new Discount("STUDENT", 10.0);
        discount.setApplicableToCustomer($person.getId());
        insert(discount);
        System.out.println("Applied student discount to: " + $person.getName());
end

rule "Loyalty Customer Discount"
    when
        $person : Person(loyaltyYears >= 5)
    then
        Discount discount = new Discount("LOYALTY", 20.0);
        discount.setApplicableToCustomer($person.getId());
        insert(discount);
        System.out.println("Applied loyalty discount to: " + $person.getName());
end
```

### 2. Decision Table Example

Create a spreadsheet-based decision table in KIE Workbench:

**File: `ShippingRules.xls`**
```
RuleTable ShippingCost
CONDITION    CONDITION    CONDITION    ACTION
orderAmount  destination  priority     shippingCost
>=           ==           ==           setShippingCost
100          "DOMESTIC"   "STANDARD"   5.99
100          "DOMESTIC"   "EXPRESS"    12.99
100          "INTERNATIONAL" "STANDARD" 15.99
100          "INTERNATIONAL" "EXPRESS"  29.99
50           "DOMESTIC"   "STANDARD"   9.99
50           "DOMESTIC"   "EXPRESS"    16.99
50           "INTERNATIONAL" "STANDARD" 25.99
50           "INTERNATIONAL" "EXPRESS"  39.99
```

### 3. DMN Decision Model

Create a Decision Model and Notation file:

**File: `LoanApproval.dmn`**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<definitions xmlns="http://www.omg.org/spec/DMN/20151101/dmn.xsd"
             xmlns:feel="http://www.omg.org/spec/FEEL/20140401"
             id="loan-approval"
             name="Loan Approval Decision"
             namespace="https://example.com/dmn/loan-approval">
  
  <decision id="loan-decision" name="Loan Decision">
    <decisionTable id="loan-table">
      <input id="credit-score" label="Credit Score">
        <inputExpression typeRef="number">
          <text>creditScore</text>
        </inputExpression>
      </input>
      <input id="income" label="Annual Income">
        <inputExpression typeRef="number">
          <text>annualIncome</text>
        </inputExpression>
      </input>
      <input id="loan-amount" label="Loan Amount">
        <inputExpression typeRef="number">
          <text>loanAmount</text>
        </inputExpression>
      </input>
      <output id="approval" label="Approval">
        <outputValues>
          <text>"APPROVED","DENIED","MANUAL_REVIEW"</text>
        </outputValues>
      </output>
      
      <rule id="rule-1">
        <inputEntry><text>&gt;= 750</text></inputEntry>
        <inputEntry><text>&gt;= 50000</text></inputEntry>
        <inputEntry><text>&lt;= annualIncome * 4</text></inputEntry>
        <outputEntry><text>"APPROVED"</text></outputEntry>
      </rule>
      
      <rule id="rule-2">
        <inputEntry><text>&lt; 600</text></inputEntry>
        <inputEntry><text>-</text></inputEntry>
        <inputEntry><text>-</text></inputEntry>
        <outputEntry><text>"DENIED"</text></outputEntry>
      </rule>
      
      <rule id="rule-3">
        <inputEntry><text>[600..750)</text></inputEntry>
        <inputEntry><text>&gt;= 40000</text></inputEntry>
        <inputEntry><text>&lt;= annualIncome * 3</text></inputEntry>
        <outputEntry><text>"MANUAL_REVIEW"</text></outputEntry>
      </rule>
      
      <rule id="rule-4">
        <inputEntry><text>-</text></inputEntry>
        <inputEntry><text>-</text></inputEntry>
        <inputEntry><text>-</text></inputEntry>
        <outputEntry><text>"DENIED"</text></outputEntry>
      </rule>
    </decisionTable>
  </decision>
</definitions>
```

## Java Model Classes

Create these Java model classes in your project:

### Person.java
```java
package com.example.model;

public class Person {
    private String id;
    private String name;
    private int age;
    private String studentId;
    private int loyaltyYears;
    
    public Person() {}
    
    public Person(String id, String name, int age) {
        this.id = id;
        this.name = name;
        this.age = age;
    }
    
    // Getters and setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public int getAge() { return age; }
    public void setAge(int age) { this.age = age; }
    
    public String getStudentId() { return studentId; }
    public void setStudentId(String studentId) { this.studentId = studentId; }
    
    public int getLoyaltyYears() { return loyaltyYears; }
    public void setLoyaltyYears(int loyaltyYears) { this.loyaltyYears = loyaltyYears; }
    
    @Override
    public String toString() {
        return String.format("Person{id='%s', name='%s', age=%d}", id, name, age);
    }
}
```

### Discount.java
```java
package com.example.model;

public class Discount {
    private String type;
    private double percentage;
    private String applicableToCustomer;
    
    public Discount() {}
    
    public Discount(String type, double percentage) {
        this.type = type;
        this.percentage = percentage;
    }
    
    // Getters and setters
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    
    public double getPercentage() { return percentage; }
    public void setPercentage(double percentage) { this.percentage = percentage; }
    
    public String getApplicableToCustomer() { return applicableToCustomer; }
    public void setApplicableToCustomer(String applicableToCustomer) { 
        this.applicableToCustomer = applicableToCustomer; 
    }
    
    @Override
    public String toString() {
        return String.format("Discount{type='%s', percentage=%.1f%%}", type, percentage);
    }
}
```

### Order.java
```java
package com.example.model;

public class Order {
    private String id;
    private double amount;
    private String destination;
    private String priority;
    private double shippingCost;
    private String customerId;
    
    public Order() {}
    
    public Order(String id, double amount, String destination, String priority) {
        this.id = id;
        this.amount = amount;
        this.destination = destination;
        this.priority = priority;
    }
    
    // Getters and setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    
    public double getAmount() { return amount; }
    public void setAmount(double amount) { this.amount = amount; }
    
    public String getDestination() { return destination; }
    public void setDestination(String destination) { this.destination = destination; }
    
    public String getPriority() { return priority; }
    public void setPriority(String priority) { this.priority = priority; }
    
    public double getShippingCost() { return shippingCost; }
    public void setShippingCost(double shippingCost) { this.shippingCost = shippingCost; }
    
    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }
}
```

## API Usage Examples

### KIE Server REST API

```bash
# 1. Check server status
curl -u kieserver:kieserver1! \
  http://localhost:8080/kie-server/services/rest/server

# 2. List containers
curl -u kieserver:kieserver1! \
  http://localhost:8080/kie-server/services/rest/server/containers

# 3. Execute rules
curl -X POST \
  -H "Content-Type: application/json" \
  -u kieserver:kieserver1! \
  http://localhost:8080/kie-server/services/rest/server/containers/instances/rules-container \
  -d '{
    "lookup": "default-stateless-ksession",
    "commands": [
      {
        "insert": {
          "object": {
            "com.example.model.Person": {
              "id": "p1",
              "name": "John Doe", 
              "age": 67,
              "loyaltyYears": 8
            }
          }
        }
      },
      {"fire-all-rules": {}},
      {
        "get-objects": {
          "out-identifier": "results"
        }
      }
    ]
  }'
```

### Kogito Decision Service API

```bash
# Health check
curl http://localhost:8080/decisions/q/health

# Execute decision (example endpoint - depends on your deployed model)
curl -X POST \
  -H "Content-Type: application/json" \
  http://localhost:8080/decisions/loan-approval \
  -d '{
    "creditScore": 720,
    "annualIncome": 65000,
    "loanAmount": 200000
  }'
```

## Project Structure in KIE Workbench

When you create a project in KIE Workbench, organize it like this:

```
my-rules-project/
├── pom.xml
├── src/
│   └── main/
│       ├── java/
│       │   └── com/example/model/
│       │       ├── Person.java
│       │       ├── Discount.java
│       │       └── Order.java
│       └── resources/
│           ├── META-INF/
│           │   └── kmodule.xml
│           └── rules/
│               ├── PersonDiscountRules.drl
│               ├── ShippingRules.xls
│               └── LoanApproval.dmn
└── target/
```

### kmodule.xml Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<kmodule xmlns="http://jboss.org/kie/6.0.0/kmodule">
    <kbase name="rules" packages="rules">
        <ksession name="ksession-rules" default="true"/>
    </kbase>
</kmodule>
```

### Maven POM Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>my-rules-project</artifactId>
    <version>1.0.0</version>
    <packaging>kjar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <drools.version>7.74.1.Final</drools.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.drools</groupId>
            <artifactId>drools-core</artifactId>
            <version>${drools.version}</version>
        </dependency>
        <dependency>
            <groupId>org.drools</groupId>
            <artifactId>drools-compiler</artifactId>
            <version>${drools.version}</version>
        </dependency>
    </dependencies>
</project>
```

## Testing Your Rules

### Unit Test Example

```java
package com.example.rules;

import org.drools.core.ClockType;
import org.drools.core.time.SessionPseudoClock;
import org.junit.Test;
import org.kie.api.KieBase;
import org.kie.api.KieBaseConfiguration;
import org.kie.api.KieServices;
import org.kie.api.conf.EventProcessingOption;
import org.kie.api.runtime.KieContainer;
import org.kie.api.runtime.KieSession;
import org.kie.api.runtime.KieSessionConfiguration;
import org.kie.api.runtime.conf.ClockTypeOption;

import static org.junit.Assert.*;

public class PersonDiscountRulesTest {
    
    @Test
    public void testSeniorDiscount() {
        KieServices kieServices = KieServices.Factory.get();
        KieContainer kieContainer = kieServices.getKieClasspathContainer();
        KieSession kieSession = kieContainer.newKieSession("ksession-rules");
        
        // Insert test data
        Person senior = new Person("p1", "John Senior", 67);
        kieSession.insert(senior);
        
        // Fire rules
        int rulesFired = kieSession.fireAllRules();
        
        // Verify results
        assertTrue("At least one rule should have fired", rulesFired > 0);
        
        // Check for discount objects
        Collection<?> discounts = kieSession.getObjects(new ClassObjectFilter(Discount.class));
        assertFalse("Should have created discount", discounts.isEmpty());
        
        Discount discount = (Discount) discounts.iterator().next();
        assertEquals("SENIOR", discount.getType());
        assertEquals(15.0, discount.getPercentage(), 0.01);
        
        kieSession.dispose();
    }
}
```

## Deployment Steps

1. **Create Project in KIE Workbench**
   - Login to http://localhost:8080/business-central/
   - Create new Space and Project
   - Add your rule files and model classes

2. **Build and Deploy**
   - Build project in workbench
   - Deploy to KIE Server via "Deploy" menu

3. **Test Rules**
   - Use REST API to test rule execution
   - Monitor via Kogito Data Index

4. **Production Deployment**
   - Export as KJAR
   - Deploy to production KIE Server instances
   - Configure load balancing and scaling

This gives you a complete starting point for developing business rules with your Drools/Kogito platform!