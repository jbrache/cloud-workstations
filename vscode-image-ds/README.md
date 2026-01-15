# Google Cloud Workstations - Custom VS Code Image with AI CLI Tools

This custom workstation configuration provides a complete development environment with VS Code and integrated AI-powered CLI tools including Claude, Goose, and Gemini CLI.

## 🚀 Features

### Core Development Environment (Always Installed)
- **VS Code Server** - Full VS Code experience in the browser
- **Oh My Zsh** - Enhanced shell with Powerlevel10k theme and autosuggestions
- **Terraform** - Infrastructure as Code management
- **Python venv** - Virtual environment support
- **Docker** - Container support (from base image)

### AI-Powered CLI Tools (Installed at Runtime)
These tools are automatically installed during workstation startup:
- **Claude** - Anthropic's Claude AI assistant via CLI (installed to `~/.local/bin/claude`)
- **Goose** - AI-powered development assistant (installed to `~/.local/bin/goose`)
- **uv** - Fast Python package installer (installed to `~/.local/bin/uv`)
- **Gemini CLI** - Google's Gemini AI (available via npx in base image)

### Optional Components (Commented Out - Enable as Needed)
These components can be enabled by uncommenting sections in the Dockerfile or startup scripts:

**In Dockerfile:**
- **k9s** - Kubernetes cluster management UI
- **GUI Desktop** - MATE desktop environment for remote desktop access
- **Build Tools** - python3-dev, build-essential (for compiling packages)
- **VS Code Extensions** - Gemini Code Assist, Google Cloud Code
- **pipx** - Python application installer

**In Startup Script (300_workstation-customization.sh):**
- **Chrome Remote Desktop** - Remote desktop access via Chrome
- **Google Chrome** - Web browser

### Additional Features
- Custom user profiles with auto-configuration
- Private networking with Cloud NAT
- Persistent home directories (200GB SSD)
- Google Cloud authentication integration
- Zsh with custom aliases and configurations
- MCP Server registration (Agent Development Kit docs)

### Optional: Scheduled Container Rebuilds
Enable automatic container image rebuilds via Cloud Build and Cloud Scheduler:
- **Cloud Build Trigger** - GitHub-connected trigger for building container images
- **Cloud Scheduler** - Cron-based scheduling (default: every Sunday at midnight UTC)
- **Service Account** - Dedicated `cloud-build-sa` for secure trigger invocation

## 📋 Prerequisites

Before deploying this custom workstation, ensure you have:

1. **Google Cloud Project** with billing enabled
2. **Required Permissions:**
   - Project Owner or Editor
   - Workstations Admin
   - Service Account Admin
   - Compute Network Admin
3. **Tools Installed:**
   - [Terraform](https://www.terraform.io/downloads) (>= 1.0)
   - [gcloud CLI](https://cloud.google.com/sdk/docs/install)
   - Git

## 🔧 Configuration

### 1. Clone the Repository

```bash
git clone <repository-url>
cd custom-image-ds
```

### 2. Configure Variables

Create a `terraform.tfvars` file based on the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:

```hcl
project_id    = "your-gcp-project-id"
environment   = "dev"
region        = "us-central1"

# Developer access configuration
developers_email = ["developer1@example.com", "developer2@example.com"]
developers_name  = ["developer1", "developer2"]

# Instance configuration (optional)
subnetwork_range   = "10.2.0.0/16"
machine_type       = "e2-standard-4"

# [Optional] Cloud Build scheduled container rebuilds
# When enabled, creates Cloud Build trigger + Cloud Scheduler for automatic image updates
# schedule_container_rebuilds = true
# github_repo_owner           = "your-github-username"
# github_repo_name            = "cloud-workstations"
# container_rebuild_schedule  = "0 0 * * 0"  # Every Sunday at midnight UTC
```

### 3. Authenticate with Google Cloud

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## 🏗️ Deployment

### Deploy with Terraform

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Review the deployment plan:**
   ```bash
   terraform plan
   ```

3. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```
   
   This will:
   - Enable required Google Cloud APIs
   - Create VPC network and subnet with Cloud NAT
   - Set up Artifact Registry for container images
   - Build and push the custom workstation container
   - Create workstation cluster and configuration
   - Deploy workstations for each developer
   - Assign IAM permissions

4. **Deployment time:** Approximately 15-20 minutes

## 🎯 What Gets Created

### Networking
- **VPC Network:** `workstations-vpc`
- **Subnet:** `{region}-workstations` (default: 10.2.0.0/16)
- **Cloud NAT:** For private instance internet access
- **Firewall Rules:** Internal communication and egress

### Container Infrastructure
- **Artifact Registry:** `workstations-vscode` repository
- **Custom Container Image:** Based on Google's Cloud Workstations base image with added tools

### Workstations Resources
- **Cluster:** `tf-ws-cluster`
- **Configuration:** `tf-ws-config`
  - Machine Type: e2-standard-4 (4 vCPU, 16 GB RAM)
  - Boot Disk: 50 GB
  - Persistent Disk: 200 GB SSD
  - Private IP only (no public IP)
- **Workstations:** One per developer in `developers_email` list

### Service Account
- **Name:** `cloud-workstations-sa`
- **Roles:**
  - Compute Network User
  - Artifact Registry Reader
  - Logging Log Writer

### Optional: Cloud Build Resources (when `schedule_container_rebuilds = true`)
- **Cloud Build Trigger:** `workstations-image-trigger` - GitHub-connected manual trigger
- **Cloud Scheduler Job:** `workstations-image-rebuild` - Scheduled trigger invocation
- **Service Account:** `cloud-build-sa` with `roles/cloudbuild.builds.editor`
- **IAM Binding:** Default Cloud Build SA granted `roles/artifactregistry.admin`

## 🔐 Access Your Workstation

### Via Google Cloud Console

1. Navigate to [Cloud Workstations](https://console.cloud.google.com/workstations)
2. Select your region
3. Click on your workstation (e.g., `workstation-developer1`)
4. Click **START** (if not already running)
5. Click **LAUNCH** to open VS Code in your browser

### Via gcloud CLI

```bash
# List workstations
gcloud workstations list \
  --cluster=tf-ws-cluster \
  --config=tf-ws-config \
  --region=us-central1

# Start a workstation
gcloud workstations start workstation-<developer-name> \
  --cluster=tf-ws-cluster \
  --config=tf-ws-config \
  --region=us-central1

# SSH into a workstation
gcloud workstations ssh workstation-<developer-name> \
  --cluster=tf-ws-cluster \
  --config=tf-ws-config \
  --region=us-central1
```

## 🤖 Using AI CLI Tools

Once inside your workstation, you can use the following AI tools:

### Claude CLI
```bash
# Start an interactive session
claude

# Get help
claude --help
```

### Goose
```bash
# Start Goose
goose

# Configure Goose
goose configure

# Get help
goose --help
```

### Gemini CLI
```bash
# Use via npx (no installation required)
npx @google/generative-ai-cli

# Or install globally
npm install -g @google/generative-ai-cli
gemini-cli
```

## 🛠️ Customization

### Modifying the Container Image

The custom image is defined in `workstation-container/Dockerfile`. After making changes:

1. **Rebuild the image:**
   ```bash
   # Force rebuild by updating the trigger
   terraform taint null_resource.build_container_image
   terraform apply
   ```

2. **Or manually build and push:**
   ```bash
   cd workstation-container
   gcloud builds submit . \
     --tag=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/workstations-vscode/workstations-vscode:latest \
     --region=us-central1
   ```

3. **Restart workstations** to use the new image

### Adding More Tools

Edit `workstation-container/Dockerfile` to add more tools. Common additions:

```dockerfile
# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# Install Python packages
RUN pip3 install pandas numpy jupyter

# Install additional CLI tools
RUN curl -LO https://example.com/tool && \
    chmod +x tool && \
    mv tool /usr/local/bin/
```

### Startup Scripts

Customize user environment in:
- `workstation-container/assets/etc/workstation-startup.d/300_workstation-customization.sh`

This script configures:
- VS Code settings
- Zsh configuration
- User permissions
- Environment variables

## 📊 Resource Management

### Starting and Stopping Workstations

**Important:** Workstations incur costs when running. Stop them when not in use.

```bash
# Stop a workstation
gcloud workstations stop workstation-<developer-name> \
  --cluster=tf-ws-cluster \
  --config=tf-ws-config \
  --region=us-central1

# Workstations auto-stop after idle timeout (configurable in Terraform)
```

### Updating Workstation Configuration

Modify `main.tf` and apply changes:

```bash
terraform apply
```

Changes to machine type, disk size, or container image require workstation recreation.

## 🧹 Cleanup

To remove all resources:

```bash
terraform destroy
```

**Warning:** This will delete:
- All workstations and their configurations
- Container images in Artifact Registry
- VPC network and firewall rules
- Service accounts and IAM bindings

**Note:** Persistent disks are deleted automatically (`reclaim_policy = "DELETE"`).

## 📁 Project Structure

```
custom-image-ds/
├── README.md                          # This file
├── main.tf                            # Main Terraform configuration
├── variables.tf                       # Variable definitions
├── provider.tf                        # Provider configuration
├── terraform.tfvars.example           # Example variables file
├── setup-steps.sh                     # Manual setup script (alternative to Terraform)
└── workstation-container/
    ├── Dockerfile                     # Custom container definition
    └── assets/
        └── etc/
            └── workstation-startup.d/
                ├── 010_add-user.sh                        # User creation script
                ├── 011_add-os-login-user.sh               # OS Login integration
                ├── 015_config_gcloud_metadata_creds_check.sh
                ├── 110_start-vscode.sh                    # VS Code startup
                └── 300_workstation-customization.sh       # Custom configurations
```

## 🐛 Troubleshooting

### Workstation won't start
- Check quota limits in your project
- Verify subnet has available IP addresses
- Review Cloud NAT configuration for private instances

### Can't access workstation
- Confirm user has `roles/workstations.user` role
- Check firewall rules allow necessary traffic
- Verify workstation is in RUNNING state

### CLI tools not found
- Ensure `/usr/local/bin` is in PATH
- Rebuild container image if recently modified
- Restart workstation to pick up new image

### Build failures
```bash
# Check Cloud Build logs
gcloud builds list --region=us-central1

# View specific build
gcloud builds log <BUILD_ID> --region=us-central1
```

## 📚 Additional Resources

- [Cloud Workstations Documentation](https://cloud.google.com/workstations/docs)
- [Customizing Container Images](https://cloud.google.com/workstations/docs/customize-container-images)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Claude CLI Documentation](https://claude.ai/docs)
- [Goose Documentation](https://github.com/block/goose)
- [Gemini API Documentation](https://ai.google.dev/)

## 📝 License

Copyright 2025 Google LLC

Licensed under the Apache License, Version 2.0. See LICENSE file for details.

## Disclaimer

This repository itself is not an officially supported Google product. The code in this repository is for demonstrative purposes only.
