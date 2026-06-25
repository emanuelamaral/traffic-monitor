curl -k -u ${OPENSERCH_USER}:'PASSWORD' -X PUT "https://localhost:9200/_index_template/suricata-kafka-template" \
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
          "source": {
            "properties": {
              "ip": { "type": "ip" }
            }
          },
          "destination": {
            "properties": {
              "ip": { "type": "ip" }
            }
          },
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
          "rule": {
            "properties": {
              "name": { "type": "keyword" }
            }
          }
        }
      }
    }
  }'
