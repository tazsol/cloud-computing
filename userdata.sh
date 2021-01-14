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

IP=$(curl icanhazip.com)

sudo mkdir -p /etc/grafana/provisioning/datasources/
sudo chmod a+rwx /etc/grafana/provisioning/datasources/

cat <<EOCF >/etc/grafana/provisioning/datasources/grafana_data_source.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: http://$IP:9090
    version: 1
    editable: false
EOCF

sudo mkdir -p /etc/grafana/provisioning/notifiers/
sudo chmod a+rwx /etc/grafana/provisioning/notifiers/

cat <<EOCF >/etc/grafana/provisioning/notifiers/grafana_notifiers.yml
notifiers:
  - name: Scale up
    type: webhook
    uid: scale_up
    org_id: 1
    is_default: false
    send_reminder: true
    disable_resolve_message: true
    frequency: "5m"
    settings:
      autoResolve: true
      httpMethod: "POST"
      severity: "critical"
      uploadImage: false
      url: "http://$IP:8090/up"
  - name: Scale down
    type: webhook
    uid: scale_down
    org_id: 1
    is_default: false
    send_reminder: true
    disable_resolve_message: true
    frequency: "5m"
    settings:
      autoResolve: true
      httpMethod: "POST"
      severity: "critical"
      uploadImage: false
      url: "http://$IP:8090/down"
EOCF


mkdir -p /etc/grafana/provisioning/dashboards/
cat <<EOCF >/etc/grafana/provisioning/dashboards/grafana_dashboards.yml
apiVersion: 1

providers:
  - name: 'Home'
    orgId: 1
    folder: ''
    type: file
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/dashboards
EOCF

sudo mkdir -p /etc/grafana/dashboards/
sudo chmod a+rwx /etc/grafana/dashboards/

cat <<EOCF >/etc/grafana/dashboards/dashboards.json
${grafana}
EOCF

# Running the service discovery agent written by Janos Pasztor - source: https://github.com/janoszen/prometheus-sd-exoscale-instance-pools
sudo docker run \
    -d \
    -v /srv/service-discovery:/var/run/prometheus-sd-exoscale-instance-pools \
    quay.io/janoszen/prometheus-sd-exoscale-instance-pools:1.0.0 \
    --exoscale-api-key ${exoscale-key} \
    --exoscale-api-secret ${exoscale-secret} \
    --exoscale-zone-id 4da1b188-dcd6-4ff5-b7fd-bde984055548 \
    --instance-pool-id ${instance-pool-id}

# Running the autoscaler written by Janos Pasztor - source: https://github.com/janoszen/exoscale-grafana-autoscaler
sudo docker run -d \
    -p 8090:8090 \
    quay.io/janoszen/exoscale-grafana-autoscaler:1.0.2 \
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

# Running Grafana
sudo docker run -d \
    -p 3000:3000 \
    -v /etc/grafana/provisioning/datasources/grafana_data_source.yml:/etc/grafana/provisioning/datasources/grafana_data_source.yml \
    -v /etc/grafana/provisioning/notifiers/grafana_notifiers.yml:/etc/grafana/provisioning/notifiers/grafana_notifiers.yml \
    -v /etc/grafana/provisioning/dashboards/grafana_dashboards.yml:/etc/grafana/provisioning/dashboards/grafana_dashboards.yml \
    -v /etc/grafana/dashboards/dashboards.json:/etc/grafana/dashboards/dashboards.json \
    grafana/grafana

