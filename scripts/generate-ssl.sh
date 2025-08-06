#!/bin/bash
# Generate SSL certificates for development/testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Blindr Services SSL Certificate Generator${NC}"
echo "========================================"

# Create SSL directory if it doesn't exist
SSL_DIR="nginx/ssl"
mkdir -p "$SSL_DIR"

# Certificate configuration
CERT_FILE="$SSL_DIR/cert.pem"
KEY_FILE="$SSL_DIR/key.pem"
DAYS=365

# Default values
COUNTRY="US"
STATE="State"
CITY="City"
ORGANIZATION="Blindr Services"
COMMON_NAME="localhost"

# Check if certificates already exist
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo -e "${YELLOW}SSL certificates already exist.${NC}"
    echo "Certificate: $CERT_FILE"
    echo "Private Key: $KEY_FILE"
    echo
    
    # Show certificate info
    echo "Current certificate information:"
    openssl x509 -in "$CERT_FILE" -text -noout | grep -A 1 "Subject:"
    openssl x509 -in "$CERT_FILE" -text -noout | grep -A 2 "Validity"
    echo
    
    read -p "Do you want to regenerate the certificates? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing certificates."
        exit 0
    fi
fi

# Interactive mode for custom values
if [ "$1" != "--auto" ]; then
    echo "Enter certificate details (press Enter for defaults):"
    echo
    
    read -p "Country Code (${COUNTRY}): " input
    COUNTRY=${input:-$COUNTRY}
    
    read -p "State/Province (${STATE}): " input
    STATE=${input:-$STATE}
    
    read -p "City (${CITY}): " input
    CITY=${input:-$CITY}
    
    read -p "Organization (${ORGANIZATION}): " input
    ORGANIZATION=${input:-$ORGANIZATION}
    
    read -p "Common Name/Domain (${COMMON_NAME}): " input
    COMMON_NAME=${input:-$COMMON_NAME}
    
    read -p "Certificate validity in days (${DAYS}): " input
    DAYS=${input:-$DAYS}
fi

echo
echo "Generating SSL certificate with the following details:"
echo "  Country: $COUNTRY"
echo "  State: $STATE"
echo "  City: $CITY"
echo "  Organization: $ORGANIZATION"
echo "  Common Name: $COMMON_NAME"
echo "  Validity: $DAYS days"
echo

# Generate private key and certificate
openssl req -x509 -nodes -days "$DAYS" -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/CN=$COMMON_NAME" \
    -addext "subjectAltName=DNS:$COMMON_NAME,DNS:localhost,IP:127.0.0.1,IP:0.0.0.0"

# Set appropriate permissions
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

echo -e "${GREEN}✓ SSL certificates generated successfully!${NC}"
echo
echo "Files created:"
echo "  Certificate: $CERT_FILE"
echo "  Private Key: $KEY_FILE"
echo
echo "Certificate details:"
openssl x509 -in "$CERT_FILE" -text -noout | grep -A 1 "Subject:"
openssl x509 -in "$CERT_FILE" -text -noout | grep -A 2 "Validity"
echo
echo -e "${YELLOW}Note: This is a self-signed certificate for development use only.${NC}"
echo "For production, use a certificate from a trusted CA (e.g., Let's Encrypt)."
echo
echo "To use with Blindr services:"
echo "  1. Start services with production profile: make up-prod"
echo "  2. Access via: https://localhost"
echo "  3. Accept the browser security warning (self-signed cert)"
echo