#!/bin/bash

OUT="central-monitor-$(date -u +"%Y%m%dT%H%M%SZ").log"
INTERVAL=8

CONTAINERS=(
  "logstash"
  "kafka"
  "opensearch-node1"
  "opensearch-node2"
)

echo "Timestamp,Container,CPUPerc,MemUsage,MemPerc,NetIO,BlockIO,PIDs" > "$OUT"

while true; do
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  docker stats --no-stream --format \
    "$NOW,{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}" \
    "${CONTAINERS[@]}" >> "$OUT"

  sleep "$INTERVAL"
done
