# VProfile Project

This repository contains the Java web application and Terraform infrastructure code for deploying the project on Google Cloud Platform (GCP). The application is a Spring-based web application for a user management and profile portal, and the infrastructure setup provisions the required networking, database, caching, and compute resources.

> Note: The legacy shell scripts used for deployment automation will be moved to a separate branch named BashScripts to keep this main branch focused on the application code and Terraform configuration.

## Project Overview

The project includes:

- A Spring MVC / Spring Security web application
- JPA-based persistence with MySQL
- RabbitMQ integration and Elasticsearch support
- Memcached integration
- Google Cloud deployment automation using Terraform
- VM startup scripts and infrastructure templates for cloud deployment

## Tech Stack

- Java 17
- Spring Framework 6
- Spring Security 6
- Hibernate / JPA
- MySQL
- Elasticsearch
- RabbitMQ
- Memcached
- Maven
- Terraform
- Google Cloud Platform

## Repository Structure

```text
.
├── src/                    # Java source code and web resources
│   ├── main/java/          # Application source code
│   ├── main/resources/     # Configuration and SQL scripts
│   └── webapp/            # JSP views, CSS, JS, and static assets
├── terraform/              # Terraform configuration for GCP deployment
│   ├── templates/          # Startup scripts for VMs
│   ├── main.tf             # Main Terraform resources
│   ├── variables.tf        # Variables definition
│   ├── outputs.tf          # Outputs
│   └── README.md           # Terraform deployment instructions
├── pom.xml                 # Maven project configuration
├── backend.sh              # Legacy deployment helper (to be moved to BashScripts branch)
├── frontend_1.sh           # Legacy deployment helper (to be moved to BashScripts branch)
├── frontend_2.sh           # Legacy deployment helper (to be moved to BashScripts branch)
├── VPC.sh                  # Legacy deployment helper (to be moved to BashScripts branch)
├── rollback.sh             # Legacy rollback helper (to be moved to BashScripts branch)
├── list.sh                 # Legacy helper script (to be moved to BashScripts branch)
└── README.md               # This file
```

## Prerequisites

Before running the project, make sure the following tools are installed:

- Java 17 or newer
- Maven
- MySQL (for local database setup)
- Terraform
- Google Cloud SDK (for GCP deployment)
- Access to a GCP project with billing enabled

## Building the Application

From the project root, run:

```bash
mvn clean package
```

This will compile the project and generate the WAR file in the target directory.

## Running Locally

1. Configure the database settings in the application properties file.
2. Create the required database schema and import the SQL files if needed.
3. Start the application with your preferred Spring runtime setup.
4. Open the application in a browser using the local server URL.

## GCP Deployment

The infrastructure is managed using Terraform in the terraform folder.

### Deploy steps

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Update the values in terraform.tfvars
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

The Terraform configuration provisions the Google Cloud resources needed for this application, including networking, database, caching, load balancing, and compute nodes.

For more details, see the Terraform documentation in [terraform/README.md](terraform/README.md).

## BashScripts Branch

The shell-based deployment files in this repository are being separated into a dedicated branch named BashScripts.

This branch will contain legacy automation scripts such as:

- backend.sh
- frontend_1.sh
- frontend_2.sh
- VPC.sh
- rollback.sh
- list.sh

This keeps the main branch cleaner and makes the app and infrastructure code easier to maintain and understand.

## Notes

- Keep environment-specific values like database passwords and SSH keys out of the source control history when possible.
- Use secure secret management in production environments.
- Review Terraform variables and startup scripts before deploying to a live cloud project.

## License

This project is intended for learning, development, and deployment experimentation. Check your organization or project guidelines before using it in production.
