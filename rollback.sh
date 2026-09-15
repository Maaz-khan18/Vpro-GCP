#!/bin/bash
set -e

PROJECT_ID="project-vsocial"          # Your GCP project ID
REGION="us-central1"
ZONE="${REGION}-a"

VPC="vprofile-vpc"

PUB_SUBNET_01="public-01"
PUB_SUBNET_02="public-02"
PRIV_SUBNET_01="private-01"
PRIV_SUBNET_02="private-02"

ROUTER="vprofile-router"
NAT="vprofile-nat"

BASTION="bastion"
DB="vprofile-db"
MEMCACHE="vprofile-memcache"

GOLDEN="vprofile-golden"
SNAPSHOT="vprofile-snapshot"
IMAGE="vprofile-image"

TEMPLATE="vprofile-template"
MIG="vprofile-mig"
HEALTH_CHECK="vprofile-hc"
BACKEND="vprofile-backend"
URL_MAP="vprofile-urlmap"
HTTP_PROXY="vprofile-http-proxy"
HTTPS_PROXY="vprofile-https-proxy"
LB_IP="vprofile-lb-ip"

HTTP_LB="vprofile-http-lb"
HTTPS_LB="vprofile-https-lb"

PRIVATE_ZONE="vprofile-private"

SUBDOMAIN="vprogcp"
DOMAIN="hkhinfotek.xyz"

echo "Setting project..."
gcloud config set project "$PROJECT_ID" --quiet


# ============================================================
#   1. DELETE LOAD BALANCER RESOURCES
# ============================================================

echo "Deleting forwarding rules..."
gcloud compute forwarding-rules delete "$HTTPS_LB" --global --quiet || true
gcloud compute forwarding-rules delete "$HTTP_LB" --global --quiet || true

echo "Deleting target proxies..."
gcloud compute target-https-proxies delete "$HTTPS_PROXY" --quiet || true
gcloud compute target-http-proxies delete "$HTTP_PROXY" --quiet || true

echo "Deleting URL map..."
gcloud compute url-maps delete "$URL_MAP" --quiet || true

echo "Deleting backend service..."
gcloud compute backend-services delete "$BACKEND" --global --quiet || true

echo "Deleting health check..."
gcloud compute health-checks delete "$HEALTH_CHECK" --global --quiet || true

echo "Releasing load balancer static IP..."
gcloud compute addresses delete "$LB_IP" --global --quiet || true


# ============================================================
#   2. DELETE MANAGED INSTANCE GROUP / TEMPLATE / IMAGE
# ============================================================

echo "Deleting MIG..."
gcloud compute instance-groups managed delete "$MIG" --zone="$ZONE" --quiet || true

echo "Deleting instance template..."
gcloud compute instance-templates delete "$TEMPLATE" --quiet || true

echo "Deleting custom image..."
gcloud compute images delete "$IMAGE" --quiet || true

echo "Deleting snapshot..."
gcloud compute snapshots delete "$SNAPSHOT" --quiet || true


# ============================================================
#   3. DELETE GOLDEN INSTANCE (if exists)
# ============================================================

echo "Deleting golden instance..."
gcloud compute instances delete "$GOLDEN" --zone="$ZONE" --quiet || true


# ============================================================
#   4. DELETE PRIVATE DNS ZONE
# ============================================================

echo "Deleting private DNS zone..."
cat <<EOF > empty-zone.txt
EOF

gcloud dns record-sets import empty-zone.txt     --zone="$PRIVATE_ZONE"     --delete-all-existing     --quiet
gcloud dns record-sets list     --zone="$PRIVATE_ZONE"     --project="$PROJECT_ID"
gcloud dns managed-zones delete $PRIVATE_ZONE --quiet



# ============================================================
#   5. DELETE CLOUD SQL + MEMCACHE
# ============================================================

echo "Deleting memcache..."
gcloud memcache instances delete "$MEMCACHE" --region="$REGION" --quiet || true

echo "Deleting SQL instance..."
gcloud sql instances delete "$DB" --quiet || true
# NEW: Poll for instance deletions (helps with immediate cleanup; max 10 min timeout)
echo "Waiting for Cloud SQL and Memcached deletions to propagate (up to 10 min)..."
for i in {1..60}; do  # 60 * 10s = 10 min
    if ! gcloud sql instances list --filter="name:$DB" --format="value(name)" | grep -q "$DB" && \
       ! gcloud memcache instances list --filter="name:$MEMCACHE" --region="$REGION" --format="value(name)" | grep -q "$MEMCACHE"; then
        echo "Instances fully deleted."
        break
    fi
    if [ $i -eq 60 ]; then
        echo "WARNING: Timeout waiting for deletions. Continuing anyway—peering may still fail due to Cloud SQL's 4-day retention."
    fi
    sleep 10
done

# ============================================================
#   6. DELETE BASTION HOST
# ============================================================

echo "Deleting bastion host..."
gcloud compute instances delete "$BASTION" --zone="$ZONE" --quiet || true


# ============================================================
#   7. DELETE FIREWALL RULES
# ============================================================

echo "Deleting firewall rules..."
gcloud compute firewall-rules delete allow-ssh-internet --quiet || true
gcloud compute firewall-rules delete allow-ssh-bastion --quiet || true
gcloud compute firewall-rules delete allow-lb-to-app --quiet || true


# ============================================================
#   8. DELETE NAT + ROUTER
# ============================================================

echo "Deleting NAT..."
gcloud compute routers nats delete "$NAT" \
    --router="$ROUTER" \
    --region="$REGION" \
    --quiet || true

echo "Deleting router..."
gcloud compute routers delete "$ROUTER" \
    --region="$REGION" \
    --quiet || true


# ============================================================
#   9. DELETE SUBNETS
# ============================================================

echo "Deleting subnets..."
gcloud compute networks subnets delete "$PUB_SUBNET_01" --region="$REGION" --quiet || true
gcloud compute networks subnets delete "$PUB_SUBNET_02" --region="$REGION" --quiet || true
gcloud compute networks subnets delete "$PRIV_SUBNET_01" --region="$REGION" --quiet || true
gcloud compute networks subnets delete "$PRIV_SUBNET_02" --region="$REGION" --quiet || true

# ============================================================
#   10. DELETE PRIVATE SERVICE ACCESS RANGE 
# ============================================================
echo "Deleting PSA allocated range..."
gcloud compute addresses delete google-psa-range \
    --global \
    --quiet
# ============================================================
#   11. DELETE SSL CERT + DNS AUTH + CERT MAP
# ============================================================

echo "Deleting certificate map entry..."
gcloud certificate-manager maps entries delete entry-"$SUBDOMAIN" \
    --map=map-"$SUBDOMAIN" --quiet || true

echo "Deleting certificate map..."
gcloud certificate-manager maps delete map-"$SUBDOMAIN" --quiet || true

echo "Deleting SSL certificate..."
gcloud certificate-manager certificates delete cert-"$SUBDOMAIN" --quiet || true

echo "Deleting DNS authorization..."
gcloud certificate-manager dns-authorizations delete auth-"$SUBDOMAIN" --quiet || true


#echo "Deleting VPC peering..."
#gcloud services vpc-peerings delete \
#    --service=servicenetworking.googleapis.com \
#    --network="$VPC" \
#    --quiet 





# ============================================================
#   12. DELETE VPC
# ============================================================

#echo "Deleting VPC..."
#gcloud compute networks delete "$VPC" --quiet || true


echo ""
echo "================================================="
echo "🔥 FULL ROLLBACK COMPLETED SUCCESSFULLY"
echo "
