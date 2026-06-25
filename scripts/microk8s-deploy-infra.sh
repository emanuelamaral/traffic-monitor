#!/usr/bin/env bash
set -e

BASE_DIR="../microk8s/dev-department"

echo "Applying namespaces..."
microk8s kubectl apply -f "$BASE_DIR/00-namespace.yaml"
microk8s kubectl apply -f "$BASE_DIR/01-dev-networkattachment.yaml"
microk8s kubectl apply -f "$BASE_DIR/suricata.yaml"
microk8s kubectl apply -f "$BASE_DIR/fluent-bit-config.yaml"
microk8s kubectl apply -f "$BASE_DIR/02-dev-probe-statefulset.yaml"

echo "Applying Hosts and Services"
# microk8s kubectl apply -f "$BASE_DIR/03-dev-webserver.yaml"
# microk8s kubectl apply -f "$BASE_DIR/04-dev-mysqlserver.yaml"
# microk8s kubectl apply -f "$BASE_DIR/05-dev-sshserver.yaml"
# microk8s kubectl apply -f "$BASE_DIR/06-dev-host-1.yaml"
# microk8s kubectl apply -f "$BASE_DIR/07-dev-host-2.yaml"
# microk8s kubectl apply -f "$BASE_DIR/08-dev-host-tcpreplay.yaml"

echo "Environment Created."

microk8s kubectl get pods -n dev -o wide
