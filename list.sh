#!/bin/bash

###
# VARIABLES
###
PROJECT_ID="project-vsocial"          # Your GCP project ID
REGION="us-central1"
ZONE="us-central1-a"

VPC_NAME="vprofile-vpc"
ROUTER_NAME="vprofile-router"
SUBNET_FILTER="network:${VPC_NAME}"

LB_IP_NAME="lb-ip"
SQL_PSA_RANGE_NAME="sql-psa-range"

PRIVATE_DNS_ZONE="vprofile-private"
MIG_GROUP_NAME="vprofile-mig"

###
# Always set project first
###
gcloud config set project "$PROJECT_ID"

echo "=================================="
echo "=== Load Balancer & Certificates =="
echo "=================================="

gcloud compute forwarding-rules list --global
gcloud compute target-http-proxies list --global
gcloud compute target-https-proxies list --global
gcloud compute url-maps list --global
gcloud compute backend-services list --global
gcloud compute health-checks list --global

# LB Static IP
gcloud compute addresses list --global | grep "$LB_IP_NAME"

# Certificate Manager
gcloud certificate-manager certificates list
gcloud certificate-manager maps list
gcloud certificate-manager dns-authorizations list


echo "==========================="
echo "=== Compute Engine ========"
echo "==========================="

gcloud compute instance-groups managed list
gcloud compute instance-templates list
gcloud compute instances list
gcloud compute images list | grep vprofile
gcloud compute snapshots list | grep vprofile
gcloud compute disks list


echo "==============================="
echo "=== Cloud SQL & Memcached ===="
echo "==============================="

gcloud sql instances list
gcloud memcache instances list --region="$REGION"

# SQL firewall rules
gcloud compute firewall-rules list --filter="name~sql OR name~mysql"


echo "============================"
echo "=== DNS Zones & Records ===="
echo "============================"

gcloud dns managed-zones list
gcloud dns record-sets list --zone="$PRIVATE_DNS_ZONE" 2>/dev/null \
    || echo "Zone $PRIVATE_DNS_ZONE deleted or not found"


echo "=============================================="
echo "=== VPC, Subnets, Router, NAT, Peering ======="
echo "=============================================="

gcloud compute networks list
gcloud compute networks subnets list --filter="$SUBNET_FILTER" 2>/dev/null \
    || echo "No subnets found for $VPC_NAME"

gcloud compute routers list
gcloud compute routers nats list --router="$ROUTER_NAME" --region="$REGION"

# Private Service Access (SQL)
gcloud compute addresses list --global | grep "$SQL_PSA_RANGE_NAME"

# VPC Peering With Service Networking
gcloud services vpc-peerings list --network="$VPC_NAME" 2>/dev/null \
    || echo "No peering found for network $VPC_NAME"


echo "==========================="
echo "=== Firewall Rules ========"
echo "==========================="

gcloud compute firewall-rules list --filter="name~allow-ssh OR name~allow-lb"


echo "==========================================="
echo "=== Enabled APIs (should be minimal) ======"
echo "==========================================="

gcloud services list --enabled \
    | grep -E "(compute|sql|dns|memcache|certificate|servicenetworking)"
