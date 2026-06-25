#!/bin/bash

NS="dev"
OUT="probe-monitoring-10.log"
INTERVAL=9

echo "Hour,Pod,CPU (m),RAM (MiB)" > "$OUT"

while true; do
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  microk8s kubectl top pod -n "$NS" --no-headers \
    | grep -E "^(probe-dev-[0-9]+|host-dev-8)" \
    | while read -r POD CPU RAM REST; do
        echo "$NOW,$POD   $CPU   $RAM" >> "$OUT"
      done

  sleep "$INTERVAL"
done
