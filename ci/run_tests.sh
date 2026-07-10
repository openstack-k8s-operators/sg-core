#!/bin/bash
set -ex

go test -v ./plugins/application/prometheus/... ./plugins/handler/ceilometer-metrics/... ./plugins/transport/socket/... ./pkg/... ./cmd/...
