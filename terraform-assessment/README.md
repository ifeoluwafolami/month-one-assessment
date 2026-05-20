# TechCorp Web Application Infrastructure — Terraform Assessment

This repository contains the complete Terraform configuration to provision TechCorp's AWS infrastructure for Month 1 Assessment. It deploys a highly available, secure, multi-tier web application environment.

---

## Architecture Overview

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16  (techcorp-vpc)                               │
│                                                                 │
│  ┌──────────────────────┐   ┌──────────────────────┐           │
│  │  Public Subnet 1     │   │  Public Subnet 2     │           │
│  │  10.0.1.0/24  AZ-1   │   │  10.0.2.0/24  AZ-2   │           │
│  │  ┌──────────────┐    │   │  ┌────────────────┐  │           │
│  │  │  Bastion     │    │   │  │   NAT GW 2     │  │           │
│  │  │  (EIP)       │    │   │  └────────────────┘  │           │
│  │  └──────────────┘    │   │                      │           │
│  │  ┌──────────────┐    │   │                      │           │
│  │  │  NAT GW 1    │    │   │                      │           │
│  │  └──────────────┘    │   │                      │           │
│  └──────────────────────┘   └──────────────────────┘           │
│            ▲                          ▲                         │
│            │   Application Load Balancer (ALB)                  │
│            └──────────────┬───────────┘                         │
│                           │                                     │
│  ┌──────────────────────┐ │ ┌──────────────────────┐           │
│  │  Private Subnet 1    │ │ │  Private Subnet 2    │           │
│  │  10.0.3.0/24  AZ-1   │ │ │  10.0.4.0/24  AZ-2   │           │
│  │  ┌──────────────┐    │ │ │  ┌────────────────┐  │           │
│  │  │  Web Server 1│◄───┘ └─►│ Web Server 2   │  │           │
│  │  └──────────────┘    │   │  └────────────────┘  │           │
│  │  ┌──────────────┐    │   │                      │           │
│  │  │  DB Server   │    │   │                      │           │
│  │  │  (PostgreSQL)│    │   │                      │           │
│  │  └──────────────┘    │   │                      │           │
│  └──────────────────────┘   └──────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### Resources Created
| Resource | Count | Details |
|---|---|---|
| VPC | 1 | 10.0.0.0/16 |
| Subnets | 4 | 2 public, 2 private across 2 AZs |
| Internet Gateway | 1 | Attached to VPC |
| NAT Gateways | 2 | One per public subnet (HA) |
| Security Groups | 4 | Bastion, Web, DB, ALB |
| EC2 Instances | 4 | 1 Bastion, 2 Web, 1 DB |
| Elastic IPs | 3 | 1 Bastion, 2 NAT GWs |
| Application Load Balancer | 1 | Multi-AZ, public |
| Target Group | 1 | HTTP/80, health checks |

---

## Prerequisites

1. **AWS Account** with appropriate IAM permissions (EC2, VPC, ELB, EIP)
2. **Terraform** >= 1.3.0 — [Install Terraform](https://developer.hashicorp.com/terraform/install)
3. **AWS CLI** configured with your credentials:
   ```bash
   aws configure
   ```
4. **EC2 Key Pair** already created in your target AWS region
5. **Your public IP** — run the following to find it:
   ```bash
   curl ifconfig.me
   ```

---

## File Structure

```
terraform-assessment/
├── main.tf                    # All AWS resource definitions
├── variables.tf               # Variable declarations
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variable file (copy → terraform.tfvars)
├── user_data/
│   ├── web_server_setup.sh    # Apache install + custom HTML page
│   └── db_server_setup.sh     # PostgreSQL install + DB setup
├── evidence/                  # Screenshots (deployment evidence)
└── README.md                  # This file
```

---

## Deployment Steps

### Step 1 — Clone the Repository

```bash
git clone https://github.com/<your-username>/month-one-assessment.git
cd month-one-assessment
```

### Step 2 — Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in your values:

```hcl
region         = "us-east-1"
environment    = "dev"
my_ip          = "YOUR_PUBLIC_IP"     # from: curl ifconfig.me
key_pair_name  = "your-key-pair"
admin_password = "YourSecureP@ss123!"
```

> ⚠️ **Never commit `terraform.tfvars` to version control** — it contains sensitive data. The `.gitignore` should exclude it.

### Step 3 — Initialize Terraform

```bash
terraform init
```

Expected output: *"Terraform has been successfully initialized!"*

### Step 4 — Validate Configuration

```bash
terraform validate
```

### Step 5 — Review Plan

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see **~30 resources** to be created.

### Step 6 — Apply Configuration

```bash
terraform apply tfplan
```

Type `yes` when prompted (or use `terraform apply -auto-approve` for the saved plan).

> ⏱️ **Estimated time:** 5–10 minutes (NAT Gateways take the longest)

### Step 7 — Retrieve Outputs

```bash
terraform output
```

Note the following values:
- `bastion_public_ip` — for SSH access
- `load_balancer_dns_name` — to access the web app
- `web_server_1_private_ip` / `web_server_2_private_ip`
- `database_private_ip`

---

## Accessing Resources

### Access Web Application

Open your browser and visit:
```
http://<load_balancer_dns_name>
```

Refresh multiple times — you should see responses from both web servers (different Instance IDs).

### SSH to Bastion Host

```bash
ssh techcorp-admin@<bastion_public_ip>
# Password: <admin_password from terraform.tfvars>
```

Or using a key pair:
```bash
ssh -i ~/.ssh/<your-key>.pem ec2-user@<bastion_public_ip>
```

### SSH to Web Servers (via Bastion)

From your local machine:
```bash
ssh -J techcorp-admin@<bastion_public_ip> techcorp-admin@<web_server_1_private_ip>
```

Or from inside the bastion:
```bash
ssh techcorp-admin@<web_server_1_private_ip>
ssh techcorp-admin@<web_server_2_private_ip>
```

### SSH to Database Server (via Bastion)

```bash
ssh -J techcorp-admin@<bastion_public_ip> techcorp-admin@<database_private_ip>
```

### Connect to PostgreSQL

From inside the DB server:
```bash
# As postgres superuser
sudo -u postgres psql

# As application user
psql -U techcorp_app -d techcorp_db -h localhost
```

From a web server (DB is accessible on port 5432):
```bash
psql -h <database_private_ip> -U techcorp_app -d techcorp_db
```

**Database credentials:**
| Role | Username | Password | Database |
|---|---|---|---|
| Superuser | `postgres` | `P0stgr3s@dmin2024!` | all |
| App user | `techcorp_app` | `App@TechC0rp2024!` | `techcorp_db` |

---

## Verify Deployment

```bash
# Check Apache status on web servers
sudo systemctl status httpd

# Check PostgreSQL status on DB server
sudo systemctl status postgresql

# Test web server locally
curl http://localhost

# Test PostgreSQL connection
psql -U techcorp_app -d techcorp_db -h localhost -c "SELECT * FROM health_check;"
```

---

## Cleanup — Destroy Infrastructure

> ⚠️ This will **permanently delete** all provisioned resources. Ensure you have saved all necessary data.

```bash
terraform destroy
```

Type `yes` to confirm. All resources will be destroyed in the correct dependency order.

**Estimated time:** 5–10 minutes

---

## Security Notes

- The Bastion Host is the **only** resource accessible from the internet (SSH port 22 restricted to your IP)
- Web servers are in **private subnets** — only accessible via Bastion or ALB
- The Database server is in a **private subnet** — only accessible from web servers and via Bastion
- PostgreSQL port 5432 is **not** exposed to the internet
- NAT Gateways allow private instances to reach the internet **outbound only** (for package installs)
- All passwords in this example should be changed to strong, unique values in production

---

## Troubleshooting

| Issue | Solution |
|---|---|
| `Error: InvalidKeyPair.NotFound` | Create the key pair in the specified region first |
| SSH timeout to Bastion | Check `my_ip` variable matches your current public IP |
| Health checks failing | Wait 3–5 min for user_data scripts to complete |
| Cannot connect to DB | Verify you're connecting from web SG or bastion SG |
| NAT Gateway timeout | NAT GW provisioning can take 2–3 minutes — be patient |

---

## Evidence Screenshots

Place deployment screenshots in the `evidence/` folder:

```
evidence/
├── 01-terraform-plan-output.png
├── 02-terraform-apply-complete.png
├── 03-aws-console-vpc.png
├── 04-aws-console-ec2-instances.png
├── 05-aws-console-alb.png
├── 06-alb-web-server-1.png
├── 07-alb-web-server-2.png
├── 08-ssh-bastion.png
├── 09-ssh-web-server-via-bastion.png
├── 10-ssh-db-server-via-bastion.png
└── 11-postgres-connection.png
```
