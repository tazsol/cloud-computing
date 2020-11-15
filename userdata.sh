#!/bin/bash
set -e
# setting to avoid configuration prompts
export DEBIAN_FRONTEND=noninteractive

# convenience script for docker installation - source: https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

mkdir -p /etc/prometheus/
sudo echo "${prometheus}" > /etc/prometheus/prometheus.yml

mkdir -p /srv/service-discovery/
chmod a+rwx /srv/service-discovery/

# Running the service discovery agent written by Janos Pasztor - source: https://github.com/janoszen/prometheus-sd-exoscale-instance-pools
sudo docker run \
    -d \
    -v /srv/service-discovery:/var/run/prometheus-sd-exoscale-instance-pools \
    janoszen/prometheus-sd-exoscale-instance-pools:1.0.0 \
    --exoscale-api-key ${exoscale-key} \
    --exoscale-api-secret ${exoscale-secret} \
    --exoscale-zone-id 4da1b188-dcd6-4ff5-b7fd-bde984055548 \
    --instance-pool-id ${instance-pool-id}

# Running Prometheus
sudo docker run -d \
    -p 9090:9090\
    -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
    -v /srv/service-discovery/:/srv/service-discovery/ \
    prom/prometheus