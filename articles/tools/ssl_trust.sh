#!/bin/sh

url="https://epheo.eu:8443/frefe"

usage () {
   echo "Usage is : $0 url"
}

if [ "X${1}X" != "XX" ]; then
   url="${1}"
else
   usage
   exit 0
fi

# Remove the "https://" prefix
url=${url#https://}
# Strip out everything after the fqdn
url=${url%%/*}

# Extract the domain and port
if [[ $url == *:* ]]; then
    # If port is specified
    fqdn=${url%:*}
    port=${url##*:}
else
    # If no port is specified, assume 443
    fqdn=$url
    port=443
fi

echo "FQDN: $fqdn"
echo "Port: $port"

crt_path=/tmp/${fqdn}.${port}.ca.crt
 
echo "" | openssl s_client -showcerts -prexit -connect "${fqdn}:${port}" 2> /dev/null | sed -n -e '/BEGIN CERTIFICATE/,/END CERTIFICATE/ p' > ${crt_path}
echo "Adding certificate from the following issuer:"
openssl x509 -in ${crt_path} -text | grep Issuer

sudo mv ${crt_path} /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

echo "Done."
