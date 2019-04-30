#!/bin/bash

# ------------------------------------------------------------------------------
# Dependency Check: Generic
# ------------------------------------------------------------------------------

if [[ -z $(doctl auth init 2>/dev/null | grep "Validating token... OK") ]]; then
  echo -e "\033[31mAn access token for doctl was not found.\033[39m"
  echo "In order to interact with DigitalOcean, doctl must authenticate using an access token."
  echo "This token can be created via the Applicatons & API section of the DigitalOcean Control Panel."
  echo "https://cloud.digitalocean.com/account/api/tokens"
  echo "When created, ensure this token has both read and write access."
  echo

  while true; do
    echo -e "\033[33mPlease provide your DigitalOcean API Token\033[39m: "
    read DO_TOKEN

    doctl auth init -t "${DO_TOKEN}" > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
      echo "\033[32mTDoctl can now communicate with DigitalOcean with the valid token.\033[39m"
      break
    else
      echo -e "\033[31mThere was an error authenticating with DigitalOcean. Please try again.\033[39m"
    fi
  done
fi
echo