#!/bin/bash

###############################################################################
# Script Name : wazuh_upgrade.sh
# Description : Wazuh Upgrade Automation Script
# Author      : Abhinand
# Note        : This upgrade tool helps upgrade from any version to the latest verion, currenlty tested till version 4.14.6
###############################################################################

set -e

#---------------------------#
# Colors
#---------------------------#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'

header() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    error "Please run this script as root or using sudo."
fi

###############################################################################
header "STEP 1 - STOPPING WAZUH SERVICES"

services=(
    wazuh-manager
    wazuh-indexer
    wazuh-dashboard
)

for service in "${services[@]}"; do
    echo "Stopping $service..."
    systemctl stop "$service"

    if systemctl is-active --quiet "$service"; then
        error "$service could not be stopped."
    else
        success "$service stopped successfully."
    fi
done

###############################################################################
header "STEP 2 - UPDATING PACKAGE REPOSITORY"

apt update

success "Package repository updated."

###############################################################################
header "STEP 3 - UPGRADING WAZUH COMPONENTS"

apt install wazuh-manager wazuh-indexer wazuh-dashboard -y

success "Wazuh packages upgraded successfully."

###############################################################################
header "STEP 4 - STARTING WAZUH SERVICES"

start_services=(
    wazuh-indexer
    wazuh-manager
    wazuh-dashboard
)

for service in "${start_services[@]}"; do
    echo "Starting $service..."
    systemctl start "$service"

    if systemctl is-active --quiet "$service"; then
        success "$service started successfully."
    else
        warning "$service is not active."
    fi
done

###############################################################################
header "STEP 5 - CHECKING SERVICE STATUS"

for service in "${start_services[@]}"; do
    echo ""
    echo "------------------------------------------------------"
    echo "Status of $service"
    echo "------------------------------------------------------"

    systemctl status "$service" --no-pager
done

###############################################################################
header "STEP 6 - VERIFYING DASHBOARD CERTIFICATES"

CERT_DIR="/etc/wazuh-dashboard/certs"

cd "$CERT_DIR" || error "Certificate directory not found."

if [[ -f dashboard-key.pem && -f dashboard.pem ]]; then

    success "dashboard-key.pem and dashboard.pem already exist."

else

    warning "Expected dashboard certificates not found."

    if [[ -f wazuh-dashboard-key.pem && -f wazuh-dashboard.pem ]]; then

        warning "Found renamed Wazuh certificates."

        echo "Renaming certificates..."

        mv wazuh-dashboard-key.pem dashboard-key.pem
        mv wazuh-dashboard.pem dashboard.pem

        success "Certificates renamed successfully."

    else

        error "Required certificate files are missing.
Neither:
    dashboard-key.pem/dashboard.pem

Nor:
    wazuh-dashboard-key.pem/wazuh-dashboard.pem

were found."

    fi
fi

###############################################################################
header "STEP 7 - RESTARTING WAZUH DASHBOARD"

systemctl restart wazuh-dashboard

sleep 5

if systemctl is-active --quiet wazuh-dashboard; then
    success "Dashboard restarted successfully."
else
    warning "Dashboard is not running."
fi

echo ""
echo "Dashboard Status"
echo "------------------------------------------------------"
systemctl status wazuh-dashboard --no-pager

###############################################################################
header "STEP 8 - DISPLAYING WAZUH VERSION"

echo ""
echo "Installed Wazuh Version:"
echo ""

if /var/ossec/bin/wazuh-control info; then
    success "Version information retrieved successfully."
else
    warning "Unable to retrieve version information."
fi

###############################################################################
header "UPGRADE COMPLETED"

success "Wazuh upgrade process has completed."

echo ""
echo "Please verify:"
echo "  • Dashboard UI"
echo "  • Indexer Health"
echo "  • Manager Connectivity"
echo "  • Agent Status"
echo ""
