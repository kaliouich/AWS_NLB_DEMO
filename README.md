
# AWS VPC with Network Load Balancer – Detailed Architecture & Terraform Documentation

## 📋 Table of Contents
- [Project Purpose](#project-purpose)
- [Architecture Overview](#architecture-overview)
- [Detailed AWS Components](#detailed-aws-components)
- [💻 The Demo Web Application](#-the-demo-web-application)
- [Network Load Balancer (Main Demonstration)](#network-load-balancer-main-demonstration)
- [Network Flow](#network-flow)
- [Security Considerations](#security-considerations)
- [Terraform Code Structure](#terraform-code-structure)
- [🚀 Deployment and Operational Scripts](#deployment-and-operational-scripts)

---

## 🎯 Project Purpose
This project demonstrates how to build a complete AWS infrastructure using Terraform, with a particular focus on the **Network Load Balancer (NLB)**.
Everything described here corresponds exclusively to what exists in the provided Terraform code.

Objectives:
- Present a complete and isolated **VPC** (CIDR: `10.0.0.0/16` by default)
- Demonstrate the role and behavior of the **NLB**
- Show the full network flow (Internet → NLB → Private EC2 → RDS)
- Provide clear technical documentation aligned with the code

---

## 🏗️ Architecture Overview
The architecture is a **three-tier web application stack** deployed across multiple availability zones within a single VPC.

The architecture includes:
- A **VPC** with public, private, and database subnets.
- A **Network Load Balancer** in the public subnets, acting as the public entry point.
- **EC2 API servers** in the private subnets, running application code.
- A private **RDS MySQL database** in its own dedicated subnets.
- **NAT Gateways** for outbound internet access for private resources.
- A **bastion host** for administrative access.
- Corresponding **route tables** and **security groups** for network isolation.



---

## 🔧 Detailed AWS Components

### **1. VPC**
The VPC is the base AWS network with a configurable isolated IP space (`var.vpc_cidr`).

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}
````

It enables:

  - Internal DNS
  - Name resolution for EC2
  - A configurable isolated IP space

-----

### **2. Subnets**

Your architecture includes three subnet types, each spanning multiple availability zones.

#### **Public Subnets**

CIDRs: `10.0.1.0/24`, `10.0.2.0/24` by default. Used for resources requiring direct internet access:

  - **NLB**
  - **NAT Gateways**
  - **Bastion Host**

<!-- end list -->

```hcl
resource "aws_subnet" "public" {
...
  map_public_ip_on_launch = true # Allows public IPs for resources like the Bastion host
}
```

#### **Private Subnets**

CIDRs: `10.0.3.0/24`, `10.0.4.0/24` by default. Used exclusively for **EC2 API servers** (not directly reachable from the Internet).

#### **Database Subnets**

CIDRs: `10.0.5.0/24`, `10.0.6.0/24` by default. Dedicated exclusively to the **RDS database** via an `aws_db_subnet_group`.

-----

### **3. Route Tables & Gateways**

#### *Internet Gateway (IGW)*

The `aws_internet_gateway.main` is attached to the VPC to enable communication between the VPC and the Internet.

#### *Public Route Table*

The `aws_route_table.public` routes all external traffic (`0.0.0.0/0`) to the **IGW**. All public subnets are associated with this table.

#### *NAT Gateway*

One `aws_nat_gateway.main` is deployed per public subnet, each with a dedicated Elastic IP (`aws_eip.nat`).

#### *Private Route Tables*

Each private subnet has its own `aws_route_table.private` that routes all external traffic (`0.0.0.0/0`) to its corresponding **NAT Gateway**. This provides instances in the private subnet (EC2 API servers) with **outbound-only** Internet access for updates and external API calls.

-----

### **4. Compute & Data Resources**

#### **EC2 API Servers (Private Subnets)**

The backend application servers (`aws_instance.api`) running the application (Apache/PHP via `user_data`).

  - They are in the **private subnets**.
  - They are associated with the `aws_security_group.api`.
  - They use an IAM instance profile (`aws_iam_instance_profile.ec2`) for SSM access (`AmazonSSMManagedInstanceCore` policy).

#### **RDS MySQL**

A private database instance (`aws_db_instance.api`) for the application data.

  - It is deployed in the **database subnets** using `aws_db_subnet_group.main`.
  - It is only accessible via the `aws_security_group.database` which allows traffic only from the API Security Group.

#### **Bastion Host**

An administrative server (`aws_instance.bastion`) for SSH access into the private network.

  - It is in a **public subnet**.
  - It uses a key pair (`var.key_name`).

-----

## 💻 The Demo Web Application

To visually and programmatically demonstrate the Load Balancer, a custom PHP application is automatically deployed to every EC2 instance via the **User Data script** (`api_server.sh`).

This application provides specific endpoints to verify traffic distribution, database connectivity, and instance health.

| Endpoint | Type | Purpose |
| :--- | :--- | :--- |
| **`/index.php`** | HTML | The landing page. It displays the **Instance ID** and **Private IP** of the specific server responding to the request. Refreshing this page allows you to "see" the NLB switching traffic between instances. |
| **`/health.php`** | JSON | Returns a JSON status object (`status: healthy`) along with server metadata. This is designed for automated health checks. |
| **`/api.php`** | JSON | Simulates a backend API response. It echoes back the client IP address and the instance ID processing the request. |
| **`/test.php`** | HTML | **Connectivity Verification.** It uses credentials injected by Terraform to attempt a connection to the RDS MySQL database. If the network flow (Private Subnet → Database Subnet) is correct, it prints a green "Database Connection: SUCCESS" message. |

### **Why display the Instance ID?**

The script queries the AWS Instance Metadata Service (`http://169.254.169.254/latest/meta-data/instance-id`) to get the unique ID of the server.
By displaying this on the frontend, we can confirm that the **Network Load Balancer** is effectively distributing traffic across multiple instances when we refresh the browser.

-----

## ⭐ Network Load Balancer (MAIN DEMONSTRATION)

The **NLB** (`aws_lb.api_nlb`) is the primary component showcased in this project. It operates at **Layer 4 (TCP)**, offering high performance, low latency, and is ideal for TCP traffic.

  - **Load Balancer**: Placed in the **public subnets**. Type: `network`.
  - **Listener**: Listens on **TCP port 80**.
  - **Target Group**: The `aws_lb_target_group.api` is configured to listen for **TCP port 80** traffic and registers the **API EC2 servers** (`aws_instance.api`) as targets. The `target_type` is `instance`.
  - **Health Check**: Uses a **TCP health check** on the traffic port (80) to ensure targets are responsive.

-----

## 🌐 Network Flow

The network traffic paths are strictly controlled by the route tables and security groups:

  * **External Access (API Request):**
    `Internet` $\rightarrow$ `NLB` (Public Subnets) $\rightarrow$ `Private EC2 API Servers`
  * **Database Communication:**
    `Private EC2 API Servers` $\rightarrow$ `RDS MySQL` (Database Subnets)
  * **Administrative Access:**
    `Admin` $\rightarrow$ `Bastion Host` (Public Subnet) $\rightarrow$ SSH to `Private EC2 API Servers`
  * **Outbound Internet Access (e.g., updates):**
    `Private EC2 API Servers` $\rightarrow$ `NAT Gateway` (Public Subnet) $\rightarrow$ `IGW` $\rightarrow$ `Internet`

-----

## 🔒 Security Considerations

  - The **API Security Group** (`aws_security_group.api`) allows **TCP port 80** from anywhere (`0.0.0.0/0`) and SSH (port 22) only from within the VPC CIDR (`10.0.0.0/16`).
  - The **Database Security Group** (`aws_security_group.database`) only accepts MySQL traffic (port 3306) from the **API Security Group**.
  - No private subnet is exposed publicly.
  - The **Bastion Security Group** (`aws_security_group.bastion`) allows controlled **SSH** access (port 22) from the internet (`0.0.0.0/0`).

-----

## 🛠️ Terraform Code Structure

```
terraform/
├── main.tf        # Main resource declarations
├── variables.tf   # Input variables (e.g., CIDR blocks, DB credentials)
├── outputs.tf     # Outputs (not fully provided, but expected)
└── user_data/
    └── api_server.sh # Script to configure the API EC2 instances (inferred from user_data call in main.tf)
```

-----

## 🚀 Deployment and Operational Scripts

The project includes several shell scripts to simplify the deployment and troubleshooting process. These scripts rely on the availability of the `terraform` and `aws` CLI tools.

| Script Name | Purpose | Description |
| :--- | :--- | :--- |
| `deploy.sh` | **Automated Deployment** | Initializes Terraform, runs `terraform plan`, executes `terraform apply -auto-approve`, waits 60 seconds for infrastructure stabilization, and then executes the `test_demo.sh` script. Finally, it outputs the NLB URL. |
| `test_demo.sh` | **Health and Load Test** | Performs end-to-end checks: checks for successful `terraform output`, tests the NLB's public health (`/health.php`) and API endpoints (`/api.php`) with `curl`, runs a multi-request test (3 requests) to confirm **load balancing** is working by checking for different `instance_id` values, and checks the health status of targets in the NLB Target Group using `aws elbv2 describe-target-health`. |
| `trubleshoot.sh` | **Diagnostics and Troubleshooting** | A utility script that leverages the AWS CLI to diagnose common issues. It checks basic connectivity (`ping` NLB DNS), verifies the health status of targets in the Target Group, lists the status (`State.Name`) of the EC2 instances, displays the API Security Group ingress rules, and checks the NLB's state. |

```
```