# Distributed Network Traffic Monitoring Architecture

This repository contains a research-oriented prototype for distributed network traffic monitoring using network intrusion detection probes, message-oriented ingestion, centralized indexing, and visualization. The implementation is based on Suricata probes, Fluent Bit telemetry forwarding, Apache Kafka buffering, Logstash normalization, OpenSearch indexing, and Grafana/OpenSearch Dashboards for analysis.

The project was designed as an experimental artifact for evaluating monitoring pipelines in containerized and segmented network scenarios. It includes a central analytics node, a message broker stack, a simple K3s-based probe deployment, and MicroK8s/Multus-based departmental topologies for validation, traffic replay, and controlled detection experiments.

> This repository is a research prototype. It is intended for controlled laboratory environments and should not be deployed directly in production without security hardening, credential management, network isolation, and operational review.

---

## 1. Architecture overview

The monitoring pipeline follows the sequence below:

```text
Observed traffic
    -> Suricata probe
    -> EVE JSON logs
    -> Fluent Bit
    -> Kafka topic: nids-logs
    -> Logstash normalization
    -> OpenSearch indices: suricata-kafka-YYYY.MM.dd
    -> Grafana / OpenSearch Dashboards
```

The repository is organized around three main execution layers.

### 1.1 Central analytics node

The central node contains the indexing and visualization components:

- two OpenSearch nodes;
- OpenSearch Dashboards;
- Grafana;
- Traefik labels for HTTPS exposure when Traefik is already configured in the host environment.

The corresponding Compose file is:

```text
docker/central-node.yaml
```

### 1.2 Message broker and processing node

The message broker stack contains:

- ZooKeeper;
- Apache Kafka;
- Logstash;
- a Logstash pipeline that consumes Suricata events from Kafka and indexes them into OpenSearch.

The corresponding Compose file is:

```text
docker/message-broker.yaml
```

### 1.3 Probe environments

The repository contains two probe deployment models.

The first model is a K3s-based consolidated deployment under:

```text
k3s/dev-department/
```

This scenario is the simplest one to install and validate. It is suitable for cases where a probe composed of Suricata and Fluent Bit is deployed without the need for additional Multus-based virtual interfaces.

The second model is a MicroK8s-based segmented deployment under:

```text
microk8s/
```

It is divided into three departmental scenarios:

- `fi-department`: general MicroK8s and Multus validation;
- `dev-department`: replay-based traffic evaluation with `tcpreplay`;
- `hr-department`: controlled threat-detection and intrusion-validation experiment with an external attacker namespace.

---

## 2. Repository structure

```text
.
├── commands/
│   ├── create-index-template.txt
│   └── create-partition.txt
├── docker/
│   ├── central-node.yaml
│   ├── Dockerfile
│   ├── message-broker.yaml
│   └── logstash/
│       ├── config/
│       │   ├── logstash.yml
│       │   └── pipelines.yml
│       └── pipeline/
│           └── logstash.conf
├── k3s/
│   └── dev-department/
│       ├── 00-namespace.yaml
│       ├── 01-dev-statefulset.yaml
│       ├── fluent-bit-config.yaml
│       └── suricata.yaml
├── microk8s/
│   ├── dev-department/
│   ├── fi-department/
│   └── hr-department/
├── results/
├── scripts/
├── .env.example
├── .gitignore
├── LICENSE
└── README.md
```


The `results/` directory stores experimental result files. Raw packet captures, generated Suricata logs, temporary EVE outputs, credentials, certificates, and local runtime files should not be committed to the repository.

---

## 3. Requirements

The central environment requires:

- Linux host or virtual machine;
- Docker and Docker Compose v2;
- sufficient memory for OpenSearch, Kafka, Logstash, and visualization services;
- Traefik already configured if the provided labels are used for public HTTPS/TCP exposure;
- DNS records pointing to the domains configured in `.env`.

The probe environments require one of the following:

- K3s for the consolidated probe scenario;
- MicroK8s with Multus enabled for segmented departmental scenarios.

Additional tools commonly used during validation include:

```bash
curl
jq
kubectl
microk8s
nmap
tcpdump
tcpreplay
```

---

## 4. Environment configuration

Copy the example environment file and adapt it to the target environment:

```bash
cp .env.example .env
```

The most relevant variables are:

```bash
KAFKA_BROKERS=kafka.example.org:9094
KAFKA_TOPIC=nids-logs
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
KAFKA_GROUP_ID=logstash-nids-group
KAFKA_EXTERNAL_HOST=kafka.example.org

OPENSEARCH_HOSTS=https://opensearch.example.org
OPENSEARCH_INITIAL_ADMIN_PASSWORD=change-me-strong-password
OPENSEARCH_USER=admin
OPENSEARCH_PASSWORD=change-me-strong-password
OPENSEARCH_PUBLIC_HOST=opensearch.example.org
OPENSEARCH_DASHBOARDS_PUBLIC_HOST=opendash.example.org

GRAFANA_PUBLIC_HOST=grafana.example.org
GRAFANA_ADMIN_PASSWORD=change-me-strong-password
```
---

## 5. Deploying the central analytics node

Start by deploying the OpenSearch and visualization stack:

```bash
docker compose --env-file .env -f docker/central-node.yaml up -d
```

Check the containers:

```bash
docker compose --env-file .env -f docker/central-node.yaml ps
```

Validate the OpenSearch cluster health:

```bash
curl -k -u "${OPENSEARCH_USER}:${OPENSEARCH_PASSWORD}" \
  "${OPENSEARCH_HOSTS}/_cluster/health?pretty"
```

If Traefik is configured correctly, the following endpoints should become available according to the domains defined in `.env`:

```text
https://opensearch.example.org
https://opendash.example.org
https://grafana.example.org
```

If Traefik is not available, expose the required service ports manually or adapt the Compose files for a local-only deployment.

---

## 6. Creating the OpenSearch index template

After OpenSearch is running, create the index template used by the normalized Suricata events. The repository provides the command template in:

```text
commands/create-index-template.txt
```

A typical execution uses the following values:

```bash
export OPENSEARCH_TEMPLATE_NAME="suricata-kafka-template"
export OPENSEARCH_INDEX_PATTERN="suricata-kafka-*"
```

Then create the template:

```bash
curl -k -u "${OPENSEARCH_USER}:${OPENSEARCH_PASSWORD}" \
  -X PUT "${OPENSEARCH_HOSTS}/_index_template/${OPENSEARCH_TEMPLATE_NAME}" \
  -H 'Content-Type: application/json' \
  -d '{
    "index_patterns": ["suricata-kafka-*"],
    "template": {
      "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 1,
        "refresh_interval": "5s"
      },
      "mappings": {
        "properties": {
          "@timestamp": { "type": "date" },
          "event_type": { "type": "keyword" },
          "event_type_flat": { "type": "keyword" },
          "alert_signature_flat": { "type": "keyword" },
          "src_ip_flat": { "type": "ip" },
          "dest_ip_flat": { "type": "ip" },
          "kubernetes": {
            "properties": {
              "pod_name": { "type": "keyword" },
              "node_name": { "type": "keyword" }
            }
          },
          "source": { "properties": { "ip": { "type": "ip" } } },
          "destination": { "properties": { "ip": { "type": "ip" } } },
          "event": {
            "properties": {
              "category": { "type": "keyword" },
              "kind": { "type": "keyword" },
              "severity": { "type": "keyword" },
              "severity_value": { "type": "integer" }
            }
          },
          "alert": {
            "properties": {
              "signature": { "type": "keyword" },
              "severity": { "type": "integer" },
              "category": { "type": "keyword" }
            }
          },
          "rule": { "properties": { "name": { "type": "keyword" } } }
        }
      }
    }
  }'
```

Validate the template:

```bash
curl -k -u "${OPENSEARCH_USER}:${OPENSEARCH_PASSWORD}" \
  "${OPENSEARCH_HOSTS}/_index_template/${OPENSEARCH_TEMPLATE_NAME}?pretty"
```

---

## 7. Deploying Kafka, ZooKeeper, and Logstash

Deploy the message broker and processing stack:

```bash
docker compose --env-file .env -f docker/message-broker.yaml up -d
```

Check the services:

```bash
docker compose --env-file .env -f docker/message-broker.yaml ps
```

> The Kafka service disables automatic topic creation. Therefore, the topic used by the probes must be created manually before the pipeline is considered ready.

Create the Kafka topic with one partition:

```bash
KAFKA_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i kafka | head -n1)

docker exec "$KAFKA_CONTAINER" kafka-topics \
  --bootstrap-server kafka:9092 \
  --create \
  --if-not-exists \
  --topic nids-logs \
  --partitions 1 \
  --replication-factor 1
```

Validate the topic:

```bash
docker exec "$KAFKA_CONTAINER" kafka-topics \
  --bootstrap-server kafka:9092 \
  --describe \
  --topic nids-logs
```

Logstash should then be able to consume from the `nids-logs` topic and index events into OpenSearch.

---

## 8. Deploying the K3s probe scenario

The K3s scenario is the simplest deployment path. It is useful for validating the probe pipeline without Multus-based network segmentation.

Install K3s using the standard installation procedure for the target system. After the cluster is available, verify that the node is ready:

```bash
kubectl get nodes -o wide
```

Before applying the probe manifests, validate DNS resolution from both the host VM and a Kubernetes pod.

First, test from the VM:

```bash
getent hosts kafka.example.org
```

Then test from inside the cluster:

```bash
kubectl apply -f k3s/dev-department/00-namespace.yaml

kubectl run -n dev dns-test --rm -it --restart=Never \
  --image=busybox:1.36 -- nslookup kafka.example.org
```

If the VM resolves the external domain but the pod does not, edit the CoreDNS ConfigMap:

```bash
kubectl edit configmap -n kube-system coredns
```

In the `Corefile`, replace:

```text
forward . /etc/resolv.conf
```

with explicit external resolvers:

```text
forward . 1.1.1.1 8.8.8.8
```

Restart CoreDNS:

```bash
kubectl rollout restart deployment -n kube-system coredns
```

Validate DNS again from inside the cluster:

```bash
kubectl run -n dev dns-test --rm -it --restart=Never \
  --image=busybox:1.36 -- nslookup kafka.example.org
```

After DNS resolution is working, configure the Kafka values used by Fluent Bit. The Fluent Bit ConfigMap contains placeholders for:

```text
${KAFKA_BROKERS}
${KAFKA_TOPIC}
```

Replace them with the external Kafka endpoint and topic name, or adapt the manifests to inject these values as container environment variables.

Then apply the K3s manifests:

```bash
kubectl apply -f k3s/dev-department/00-namespace.yaml
kubectl apply -f k3s/dev-department/01-suricata.yaml
kubectl apply -f k3s/dev-department/02-fluent-bit-config.yaml
kubectl apply -f k3s/dev-department/03-dev-statefulset.yaml
```

Check the pods:

```bash
kubectl get pods -n dev -o wide
```

Inspect the probe logs:

```bash
kubectl logs -n dev statefulset/dev-probe -c suricata
kubectl logs -n dev statefulset/dev-probe -c fluent-bit
```

---

## 9. Deploying the MicroK8s segmented scenarios

The MicroK8s deployment uses Multus to attach pods to department-specific bridge networks. This enables traffic observation through Suricata probes listening on host bridges such as `br-fi`, `br-dev`, and `br-hr`.

### 9.1 Installing or resetting MicroK8s

The repository includes a destructive reset script:

```text
scripts/microk8s-restart.sh
```

It removes the current MicroK8s installation, cleans CNI state, deletes department bridges if present, installs MicroK8s, enables required addons, and enables Multus.

Run it only in a disposable test VM:

```bash
sudo bash scripts/microk8s-restart.sh
```

Alternatively, install MicroK8s manually and enable the required addons:

```bash
sudo snap install microk8s --classic --channel=1.32/stable
microk8s status --wait-ready
microk8s enable dns
microk8s enable hostpath-storage
microk8s enable helm3
microk8s enable community
microk8s enable multus
microk8s status --wait-ready
```

Validate the cluster:

```bash
microk8s kubectl get nodes -o wide
microk8s kubectl get pods -n kube-system | grep -i multus
```

### 9.2 Financial department validation

The financial department is useful for validating the general MicroK8s/Multus setup:

```bash
microk8s kubectl apply -f microk8s/fi-department/
microk8s kubectl get pods -n fi -o wide
```

Validate that the bridge exists on the host:

```bash
ip addr show br-fi
```

Inspect the probe:

```bash
microk8s kubectl logs -n fi statefulset/probe-fi -c suricata
microk8s kubectl logs -n fi statefulset/probe-fi -c fluent-bit
```

### 9.3 Development department replay experiment

The development department contains a `tcpreplay` workload for replay-based traffic experiments.

The PCAP files are not included in this repository. Download the captures from:

```text
https://tcpreplay.appneta.com/wiki/captures.html
```

The replay manifest expects the following files:

```text
smallFlows.pcap
bigFlows.pcap
```

Create a local PCAP directory on the MicroK8s host and place the files there:

```bash
mkdir -p /absolute/path/to/dev-department/pcaps
```

Then update the `hostPath.path` field in:

```text
microk8s/dev-department/09-dev-host-tcpreplay.yaml
```

The path must be absolute. Kubernetes does not expand shell variables such as `$USER` inside `hostPath.path`.

Apply the development environment:

```bash
microk8s kubectl apply -f microk8s/dev-department/00-namespace.yaml
microk8s kubectl apply -f microk8s/dev-department/01-dev-networkattachment.yaml
microk8s kubectl apply -f microk8s/dev-department/02-suricata.yaml
microk8s kubectl apply -f microk8s/dev-department/03-fluent-bit-config.yaml
microk8s kubectl apply -f microk8s/dev-department/04-dev-probe-statefulset.yaml
microk8s kubectl apply -f microk8s/dev-department/05-dev-mysqlserver.yaml
microk8s kubectl apply -f microk8s/dev-department/06-dev-webserver.yaml
microk8s kubectl apply -f microk8s/dev-department/07-dev-host-1.yaml
microk8s kubectl apply -f microk8s/dev-department/08-dev-host-2.yaml
microk8s kubectl apply -f microk8s/dev-department/09-dev-host-tcpreplay.yaml
```

Follow the replay pod logs:

```bash
microk8s kubectl logs -n dev pod/tcpreplay-dev -c tcpreplay -f --timestamps
```

The helper script below stores the replay logs in a local file:

```bash
bash scripts/host-dev-8-10-replicas.sh
```

### 9.4 Human resources threat-detection experiment

The human resources scenario includes:

- an internal HR network;
- a proxy bridge between the HR network and an external attacker network;
- a Suricata probe listening on `br-hr`;
- a vulnerable multi-service host;
- an external attacker pod in the `internet` namespace;
- a Python runner for controlled malicious and benign test executions.

Apply the HR network and probe resources:

```bash
microk8s kubectl apply -f microk8s/hr-department/00-namespace.yaml
microk8s kubectl apply -f microk8s/hr-department/01-hr-networkattachment.yaml
microk8s kubectl apply -f microk8s/hr-department/01b-hr-internet-networkattachment.yaml
microk8s kubectl apply -f microk8s/hr-department/01c-hr-proxy-networkattachment.yaml
microk8s kubectl apply -f microk8s/hr-department/02-proxy-bridge-hr.yaml
microk8s kubectl apply -f microk8s/hr-department/03-suricata.yaml
microk8s kubectl apply -f microk8s/hr-department/04-fluent-bit-config.yaml
microk8s kubectl apply -f microk8s/hr-department/05-hr-probe-statefulset.yaml
microk8s kubectl apply -f microk8s/hr-department/06-hr-webserver.yaml
microk8s kubectl apply -f microk8s/hr-department/07-hr-mysqlserver.yaml
microk8s kubectl apply -f microk8s/hr-department/08-hr-host-1.yaml
microk8s kubectl apply -f microk8s/hr-department/09-hr-host-2.yaml
microk8s kubectl apply -f microk8s/hr-department/10-vuln-host.yaml
```

Apply the attacker namespace and pod:

```bash
microk8s kubectl apply -f microk8s/hr-department/pod-attacker/00-internet-namespace.yaml
microk8s kubectl apply -f microk8s/hr-department/pod-attacker/01-internet-networkattachment.yaml
microk8s kubectl apply -f microk8s/hr-department/pod-attacker/02-pod-attacker.yaml
```

The attacker pod installs several packages at startup. Depending on the network connection and package mirror speed, wait approximately 5 to 10 minutes before executing the detection test suite.

Check whether the attacker pod is ready:

```bash
microk8s kubectl logs -n internet pod/pod-attacker -c attacker -f
```

Run the controlled test suite:

```bash
microk8s kubectl -n internet exec pod-attacker -c attacker -- \
  bash -lc 'SAMPLES_PER_RUN=20 WAIT_AFTER_S=8 python3 /opt/attack-runner/run_suite.py'
```

The runner writes ground-truth records to:

```text
/opt/out/gt.jsonl
```

To inspect Suricata events directly from the HR probe:

```bash
microk8s kubectl -n hr exec probe-hr-0 -c suricata -- \
  tail -f /var/log/suricata/eve.json
```

To export EVE events for offline analysis:

```bash
mkdir -p microk8s/hr-department/eve-out

microk8s kubectl -n hr exec probe-hr-0 -c suricata -- \
  cat /var/log/suricata/eve.json > microk8s/hr-department/eve-out/eve_attacker.jsonl
```

Then run the binary detection analysis script:

```bash
python3 microk8s/hr-department/opt/out/analyze_binary.py \
  microk8s/hr-department/opt/out/gt.jsonl \
  microk8s/hr-department/eve-out/eve_attacker.jsonl \
  12 \
  10.0.0.43
```

---

## 10. Monitoring experiments

The repository includes helper scripts for collecting resource usage during experiments.

Monitor central containers:

```bash
bash scripts/central-monitor.sh
```

Monitor MicroK8s probe resource usage:

```bash
bash scripts/probe-monitoring-10.sh
```

Follow the development replay workload:

```bash
bash scripts/host-dev-8-10-replicas.sh
```

Generated monitoring logs are ignored by Git and should be stored separately when preparing experiment artifacts.

---

## 11. OpenSearch and Grafana validation

After the pipeline is running, confirm that events are reaching OpenSearch:

```bash
curl -k -u "${OPENSEARCH_USER}:${OPENSEARCH_PASSWORD}" \
  "${OPENSEARCH_HOSTS}/suricata-kafka-*/_search?size=1&pretty"
```

Useful OpenSearch fields include:

```text
@timestamp
event_type
event_type_flat
alert.signature
alert.severity
alert_signature
source.ip
destination.ip
src_ip_flat
dest_ip_flat
kubernetes.pod_name
kubernetes.node_name
rule.name
event.severity
```

In Grafana, create an OpenSearch data source pointing to the OpenSearch endpoint and use the index pattern:

```text
suricata-kafka-*
```

Typical dashboard variables include:

```text
kubernetes.pod_name
event_type
alert.severity
alert.signature
source.ip
destination.ip
```

---

## 12. Important implementation notes

### 12.1 DNS inside Kubernetes

If the host VM resolves external domains but Kubernetes pods do not, the issue is usually related to CoreDNS forwarding. In that case, edit the CoreDNS ConfigMap and replace:

```text
forward . /etc/resolv.conf
```

with:

```text
forward . 1.1.1.1 8.8.8.8
```

Then restart CoreDNS:

```bash
kubectl rollout restart deployment -n kube-system coredns
```

For MicroK8s, use:

```bash
microk8s kubectl rollout restart deployment -n kube-system coredns
```

### 12.2 Kafka topic creation

Kafka topic auto-creation is disabled. The `nids-logs` topic must be created manually before the probes start sending events.

### 12.3 Fluent Bit variables

The Fluent Bit ConfigMaps refer to Kafka through placeholders. Before applying the manifests, replace or inject:

```text
KAFKA_BROKERS
KAFKA_TOPIC
```

### 12.4 HostPath paths

Kubernetes `hostPath.path` fields must be absolute paths. Shell variables such as `$USER` are not expanded inside Kubernetes manifests.

### 12.5 PCAP files

The PCAP files used in replay experiments are intentionally not committed to the repository. Download them from the public tcpreplay capture repository and place them in the host directory referenced by the replay pod.

### 12.6 Attacker pod initialization

The attacker pod installs packages during startup. Wait until the installation has completed before executing the runner. This usually takes 5 to 10 minutes depending on network speed.

### 12.7 Logstash image build

The broker Compose file uses a custom Logstash build context. If the Dockerfile is not present in your local copy, add the Dockerfile used to install the OpenSearch output plugin or replace the `build` block with a compatible prebuilt Logstash image.

---

## 13. Security and ethical use

This repository includes controlled offensive traffic generation only for laboratory validation of network detection. Some manifests intentionally deploy weak services and default credentials. These resources must remain isolated from production networks and from the public Internet.

Use the attack runner and scanning workloads only in environments that you own or are explicitly authorized to test.

Before adapting this project to real infrastructure, review at least the following aspects:

- secret handling and credential storage;
- TLS enforcement and certificate validation;
- Kafka listener security;
- OpenSearch authentication and authorization;
- dashboard access control;
- firewall rules and public exposure;
- retention and privacy requirements for network telemetry.

---

## 14. Troubleshooting

### OpenSearch does not respond

Check container health:

```bash
docker compose --env-file .env -f docker/central-node.yaml ps
```

Check logs:

```bash
docker compose --env-file .env -f docker/central-node.yaml logs -f opensearch-node1 opensearch-node2
```

### Kafka topic is missing

List topics:

```bash
docker exec "$KAFKA_CONTAINER" kafka-topics \
  --bootstrap-server kafka:9092 \
  --list
```

Create the topic again with `--if-not-exists`.

### Pods cannot resolve the Kafka domain

Apply the CoreDNS forwarding fix described in Section 12.1.

### Fluent Bit does not send events

Check whether the Kafka broker and topic are reachable from the pod. Then inspect Fluent Bit logs:

```bash
kubectl logs -n dev statefulset/dev-probe -c fluent-bit
```

For MicroK8s:

```bash
microk8s kubectl logs -n hr statefulset/probe-hr -c fluent-bit
```

### Suricata does not capture traffic

Confirm that the target bridge exists and that Suricata is listening on the correct interface:

```bash
ip link show br-hr
microk8s kubectl -n hr describe pod probe-hr-0
```

For the development and financial departments, check `br-dev` and `br-fi` respectively.

### The tcpreplay pod fails with missing PCAP files

Verify the absolute `hostPath.path` configured in:

```text
microk8s/dev-department/09-dev-host-tcpreplay.yaml
```

Then confirm that the host directory contains:

```text
smallFlows.pcap
bigFlows.pcap
```

---

## 15. Results

The `results/` directory contains experimental result files generated during previous executions. These files are kept as research artifacts and should be interpreted together with the corresponding scripts, deployment conditions, and workload descriptions.

New raw logs, packet captures, and temporary JSONL outputs should not be committed unless they are intentionally curated as part of a reproducibility package.

---

## 16. License

This project is distributed under the MIT License. See the `LICENSE` file for details.
