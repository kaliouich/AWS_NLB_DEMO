#!/bin/bash

set -e

echo "🚀 Deploying VPC NLB API Infrastructure..."

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init

# Plan deployment
echo "📋 Planning deployment..."
terraform plan

# Apply configuration
echo "🛠️ Applying configuration..."
terraform apply -auto-approve

# Wait for infrastructure to be ready
echo "⏳ Waiting for infrastructure to stabilize..."
sleep 60

# Run tests
echo "🧪 Running tests..."
chmod +x test_demo.sh
./test_demo.sh

echo "✅ Deployment complete!"
echo "🌐 NLB URL: http://$(terraform output -raw nlb_dns_name)"