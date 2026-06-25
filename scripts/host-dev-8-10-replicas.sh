#!/bin/bash

NS="dev"
POD="tcpreplay-dev"
CONTAINER="tcpreplay"
OUT="host-dev-8-10-replicas.log"

microk8s kubectl logs -n "$NS" "$POD" -c "$CONTAINER" -f --timestamps > "$OUT"
