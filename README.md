# terraformProj
# AWS 2-Tier Architecture with Terraform

This Terraform project creates a highly available, multi-AZ **N-Tier architecture** in AWS. It provisions the following components:

- **Custom VPC**
- **Public & Private Subnets** in two Availability Zones
- **Internet Gateway & NAT Gateway**
- **Public & Private Application Load Balancers (ALBs)**
- **Proxy Servers (public EC2 instances with NGINX reverse proxy)**
- **Web Servers (private EC2 instances running Apache)**
- **Security Groups** for fine-grained access control

---

## 📁 Project Structure
.
├── main.tf # Main configuration file
├── variables.tf # Input variables
├── outputs.tf # Output values
├── vpc/ # VPC module
├── subnet/ # Subnet module
├── gw/ # Internet Gateway module
├── natgw/ # NAT Gateway module
├── rt/ # Route table module
├── secgroup/ # Security group module
├── alb/ # Load balancer module
├── instance/ # Proxy server module 
└── web/ # Web server module


---

## 🏗️ Components Provisioned

### 🔹 VPC & Networking

- Custom VPC (`10.0.0.0/16`)
- 4 Subnets (2 public, 2 private across AZs `us-east-1a` and `us-east-1b`)
- Internet Gateway for public access
- NAT Gateway for internet access from private subnets
- Route Tables with appropriate associations

### 🔹 Security Groups

- **Public ALB SG** – Allows inbound HTTP traffic from `0.0.0.0/0`
- **Proxy SG** – Allows:
  - HTTP from ALB SG
  - SSH from anywhere
- **Private ALB SG** – Allows HTTP from proxy SG
- **Web Server SG** – Allows:
  - HTTP from private ALB SG
  - SSH from proxy SG

### 🔹 Load Balancers

- **Public ALB**:
  - Listens on port 80
  - Routes traffic to proxy servers
- **Private ALB**:
  - Internal-only
  - Routes traffic to web servers

### 🔹 EC2 Instances

- **Proxy Servers**:
  - Located in public subnets
  - Run NGINX as reverse proxy pointing to private ALB
- **Web Servers**:
  - Located in private subnets
  - Run Apache with custom HTML content

---

## 🚀 Getting Started

### 🔧 Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.0+
- AWS CLI with credentials configured
- SSH keypair (`zizo.pem`) available locally
- IAM user with appropriate permissions

