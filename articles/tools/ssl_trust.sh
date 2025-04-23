#!/bin/bash
# filepath: /blog/articles/tools/ssl_trust.sh
#
# Script to download and trust SSL certificates from remote servers
# Automatically detects and works with most Linux distributions
#
# Usage: ./ssl_trust.sh <url>
# Example: ./ssl_trust.sh https://myserver.example.com:8443/api

# Exit on error, undefined variable reference, and prevent errors in pipelines from being masked
set -euo pipefail

# Default URL (for testing/example only)
DEFAULT_URL="https://epheo.eu:8443/frefe"

usage() {
   echo "Usage: $(basename "$0") <url>"
   echo "Example: $(basename "$0") https://myserver.example.com:8443/api"
   echo "This script downloads and installs the SSL certificate from the specified URL."
}

# Check for required commands
for cmd in openssl sed grep; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' not found." >&2
        exit 1
    fi
done

# Parse arguments
if [ $# -ge 1 ]; then
   url="${1}"
else
   usage
   echo -e "\nNo URL provided. Using default URL: ${DEFAULT_URL}"
   url="${DEFAULT_URL}"
fi

# Remove the "https://" or "http://" prefix
url="${url#http://}"
url="${url#https://}"

# Strip out everything after the fqdn
url="${url%%/*}"

# Extract the domain and port
if [[ $url == *:* ]]; then
    # If port is specified
    fqdn="${url%:*}"
    port="${url##*:}"
else
    # If no port is specified, assume 443
    fqdn="$url"
    port="443"
fi

echo "FQDN: $fqdn"
echo "Port: $port"

crt_path="/tmp/${fqdn}.${port}.ca.crt"
 
# Get the certificate
echo "Retrieving certificate from ${fqdn}:${port}..."
if ! echo "" | openssl s_client -showcerts -prexit -connect "${fqdn}:${port}" 2>/dev/null | sed -n -e '/BEGIN CERTIFICATE/,/END CERTIFICATE/ p' > "${crt_path}"; then
    echo "Error: Failed to retrieve certificate." >&2
    exit 1
fi

# Verify we have a valid certificate
if ! grep -q "BEGIN CERTIFICATE" "${crt_path}"; then
    echo "Error: Retrieved file doesn't appear to be a valid certificate." >&2
    exit 1
fi

echo "Adding certificate from the following issuer:"
openssl x509 -in "${crt_path}" -text | grep Issuer

# Detect the OS and certificate store location
if [ -d "/etc/pki/ca-trust/source/anchors" ]; then
    # RHEL/CentOS/Fedora
    sudo mv "${crt_path}" /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust
elif [ -d "/etc/ca-certificates/trust-source/anchors" ]; then
    # Arch Linux
    sudo mv "${crt_path}" /etc/ca-certificates/trust-source/anchors/
    sudo trust extract-compat
else
    echo "Error: Could not determine the certificate store location for your OS." >&2
    echo "Certificate saved to ${crt_path}, please install it manually." >&2
    exit 1
fi

echo "Certificate successfully installed and trusted."
