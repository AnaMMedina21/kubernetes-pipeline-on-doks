#!/bin/bash
BASEDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )")
source "${BASEDIR}/scripts/functions.sh"

# Create a DNS A record
echo -e "\033[33mWhich domain will be the root domain for the ingress?\033[39m"

VALID_DOMAINS=($(doctl compute domain list -o text | awk '{if(NR>1)print $1}'))
select_option "${VALID_DOMAINS[@]}"
choice=$?
DOMAIN_NAME="${VALID_DOMAINS[$choice]}"
DNS_RECORD_NAME="*"

# Load Balancer IP validation.
echo "Fetching load balancer information..."
echo

KUBE_LB=($(kubectl get svc --all-namespaces | grep LoadBalancer | awk '{print $5}'))
DO_LB=($(doctl compute load-balancer list -o text | awk '{if(NR>1)print $2}'))

# Ensure load balancers in Kubernetes match those fetched from DigitalOcean.
MATCHING=()
for i in $KUBE_LB; do
  for k in $DO_LB; do
    if [[ "$i" == "$k" ]]; then
      MATCHING+=("$i")
    fi
  done
done

if [[ "${#MATCHING[@]}" -gt 1 ]]; then
  echo "\033[33mMultiple load balancers were found. Choose the desired load balancer to be used.\033[39m"
  
  select_option "${MATCHING[@]}"
  choice=$?
  LOAD_BALANCER_IP="${MATCHING[$choice]}"
else
  LOAD_BALANCER_IP="${MATCHING}" # Since there will only be one.
fi

echo "A DNS A record for the domain will be created with the following information."
echo "Domain: ${DOMAIN_NAME}"
echo "Type: A"
echo "Record: ${DNS_RECORD_NAME}"
echo "Host will direct to bounded load balancer IP: ${LOAD_BALANCER_IP}"
echo

echo "Creating DNS A record..."
doctl compute domain records create "${DOMAIN_NAME}" \
  --record-type A \
  --record-name "${DNS_RECORD_NAME}" \
  --record-data "${LOAD_BALANCER_IP}" \
  --record-priority 0 \
  --record-ttl 1801 \
  --record-weight 0 > /dev/null

if [[ $? -eq 0 ]]; then
  echo -e "\033[32mDNS A record has been created.\033[39m"
else
  echo -e "\033[31mThere was a problem creating the DNS A record.\033[39m"
fi
