#!/bin/bash
set -ex

# Only the code used in RHOSO is tested, because some of the other plugins need additional external dependencies (like a running Loki). 
go test -v ./plugins/application/prometheus/... ./plugins/handler/ceilometer-metrics/... ./plugins/transport/socket/... ./pkg/... ./cmd/...
