#!/bin/bash

echo "🔍 Troubleshooting VPC NLB Setup..."

# Get outputs
NLB_DNS=$(terraform output -raw nlb_dns_name)
TARGET_GROUP_ARN=$(terraform output -raw nlb_target_group_arn)

echo "1. Testing basic connectivity..."
ping -c 3 $NLB_DNS

echo ""
echo "2. Checking target group health..."
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN

echo ""
echo "3. Checking EC2 instance status..."
aws ec2 describe-instances --filters "Name=tag:Name,Values=api-server-*" --query 'Reservations[].Instances[].[InstanceId, State.Name, PrivateIpAddress]' --output table

echo ""
echo "4. Checking security groups..."
aws ec2 describe-security-groups --filters "Name=group-name,Values=api-sg" --query 'SecurityGroups[0].IpPermissions' --output table

echo ""
echo "5. Testing HTTP connectivity directly to instances..."
INSTANCE_IDS=$(terraform output -raw api_instance_ids | tr ',' ' ')
for instance_id in $INSTANCE_IDS; do
    private_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
    echo "   Testing $instance_id ($private_ip)..."
    # This would require SSH access, but we can check if it's running
    aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$instance_id" --query 'InstanceInformationList[0].PingStatus' --output text
done

echo ""
echo "6. Checking NLB..."
aws elbv2 describe-load-balancers --names api-nlb --query 'LoadBalancers[0].State' --output table