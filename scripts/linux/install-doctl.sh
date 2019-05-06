#!/bin/bash

VER='1.16.0'
curl -sL "https://github.com/digitalocean/doctl/releases/download/v$VER/doctl-$VER-linux-amd64.tar.gz" | tar -xzv
sudo mv ~/doctl /usr/local/bin
