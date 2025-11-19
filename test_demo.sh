#!/bin/bash

set -e

echo "=== VPC NLB API Demo ==="
echo ""

# Check if terraform outputs are available
echo "1. Checking Terraform outputs..."
if ! terraform output nlb_dns_name > /dev/null 2>&1; then
    echo "   ❌ Terraform outputs not available. Please run 'terraform apply' first."
    exit 1
fi

# Get Terraform outputs
NLB_DNS=$(terraform output -raw nlb_dns_name)
BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "Not available")
TARGET_GROUP_ARN=$(terraform output -raw nlb_target_group_arn)
DB_ENDPOINT=$(terraform output -raw database_endpoint)

echo "   ✅ NLB DNS: $NLB_DNS"
echo "   ✅ Bastion IP: $BASTION_IP"
echo "   ✅ DB Endpoint: $DB_ENDPOINT"
echo ""

# Wait for instances to be fully ready
echo "2. Waiting for infrastructure to be ready..."
sleep 30

echo ""
echo "3. Testing Load Balancer Endpoints..."
echo "   Testing health endpoint:"
HEALTH_RESPONSE=$(curl -s --connect-timeout 10 "http://$NLB_DNS/health.php" || echo "CONNECTION_FAILED")
if [ "$HEALTH_RESPONSE" != "CONNECTION_FAILED" ]; then
    echo "   ✅ Health endpoint response:"
    echo "$HEALTH_RESPONSE" | jq . 2>/dev/null || echo "$HEALTH_RESPONSE" | head -n 5
else
    echo "   ❌ Cannot reach health endpoint"
fi

echo ""
echo "   Testing API endpoint:"
API_RESPONSE=$(curl -s --connect-timeout 10 "http://$NLB_DNS/api.php" || echo "CONNECTION_FAILED")
if [ "$API_RESPONSE" != "CONNECTION_FAILED" ]; then
    echo "   ✅ API endpoint response:"
    echo "$API_RESPONSE" | jq . 2>/dev/null || echo "$API_RESPONSE" | head -n 5
else
    echo "   ❌ Cannot reach API endpoint"
fi

echo ""
echo "   Testing multiple requests (load balancing test):"
for i in {1..3}; do
    INSTANCE_ID=$(curl -s --connect-timeout 5 "http://$NLB_DNS/api.php" | grep -o '"instance_id":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    echo "   Request $i served by: $INSTANCE_ID"
    sleep 1
done

echo ""
echo "4. Checking Load Balancer Target Health..."
if [ -n "$TARGET_GROUP_ARN" ]; then
    aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN" --query 'TargetHealthDescriptions[].[Target.Id, TargetHealth.State]' --output table
else
    echo "   ❌ Target group ARN not available"
fi

echo ""
echo "5. Checking EC2 Instances Status..."
aws ec2 describe-instances --filters "Name=tag:Name,Values=api-server-*" --query 'Reservations[].Instances[].[InstanceId, PrivateIpAddress, State.Name]' --output table

echo ""
echo "6. Checking RDS Database Status..."
aws rds describe-db-instances --db-instance-identifier api-db --query 'DBInstances[].[DBInstanceIdentifier, DBInstanceStatus, Engine, EngineVersion]' --output table

echo ""
echo "7. Network Information:"
echo "   VPC ID: $(terraform output -raw vpc_id)"
echo "   API Instance IPs: $(terraform output -raw api_instance_private_ips 2>/dev/null || echo "Not available")"

echo ""
echo "=== Demo Complete ==="
echo ""
echo "🔧 Troubleshooting Commands:"
echo "   curl -v http://$NLB_DNS/health.php"
echo "   curl http://$NLB_DNS/api.php"
echo "   aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN"