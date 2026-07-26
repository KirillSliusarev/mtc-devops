#!/usr/bin/env bash
# NO set -e

# =============================================================================
# Automated chaos test — non-interactive, 3 min per scenario
# Generates background traffic throughout so Grafana shows clear patterns
# =============================================================================

APP_URL="http://localhost:30133"
HARBOR_URL="http://localhost:30002"
NAMESPACE="demo-app"
HARBOR_NS="harbor"
TRAFFIC_PID=""

cleanup() {
    if [ -n "${TRAFFIC_PID}" ]; then
        kill "${TRAFFIC_PID}" 2>/dev/null
    fi
    kubectl delete envoyfilter harbor-nginx-abort -n "${HARBOR_NS}" --ignore-not-found 2>/dev/null
    kubectl delete vs backend-latency -n "${NAMESPACE}" --ignore-not-found 2>/dev/null
    kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS=0 2>/dev/null
    kubectl delete authorizationpolicy deny-backend-to-db -n "${NAMESPACE}" --ignore-not-found 2>/dev/null
    echo "Cleanup done."
}
trap cleanup EXIT

# =============================================================================
# Background traffic generator: hits /api/status every 1 second
# =============================================================================
generate_traffic() {
    while true; do
        curl -s -o /dev/null --max-time 10 "${APP_URL}/api/status" 2>/dev/null
        sleep 1
    done
}

echo ""
echo ""
echo ""
echo ""
echo ""
echo "App:      ${APP_URL}"
echo "Grafana:  http://localhost:30000 → Chaos Engineering Demo"
echo ""

# Start background traffic
echo "Starting background traffic generator..."
generate_traffic &
TRAFFIC_PID=$!
sleep 2

# Helper: run a scenario phase
phase() {
    local name="$1"
    local duration="$2"
    echo ""
    echo "── ${name} (${duration}s) ──────────────────────────────"
    local elapsed=0
    while [ ${elapsed} -lt ${duration} ]; do
        RESPONSE=$(curl -s --max-time 10 "${APP_URL}/api/status" 2>/dev/null || echo "TIMEOUT")
        DB_STATUS=$(echo "${RESPONSE}" | grep -o '"db":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "?")
        DB_MS=$(echo "${RESPONSE}" | grep -o '"db_response_ms": [0-9]*' | grep -o '[0-9]*' 2>/dev/null || echo "?")
        HARBOR_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${HARBOR_URL}/api/v2.0/health" 2>/dev/null || echo "000")
        echo "  [${elapsed}/${duration}s] api_db=${DB_STATUS} api_ms=${DB_MS} harbor_api=${HARBOR_CODE}"
        sleep 10
        elapsed=$((elapsed + 10))
    done
}

# =============================================================================
# Scenario 1: HTTP Latency (5s, 50%)
# =============================================================================
echo ""
echo ""
echo ""
echo ""

phase "BASELINE (normal)" 30

echo "  INJECTING 3s Istio fault.delay on demo-vs (VirtualService)"
cat <<YAML | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: demo-vs
  namespace: ${NAMESPACE}
spec:
  hosts: ['*']
  gateways: ['istio-system/demo-gateway']
  http:
  - match: [{uri: {prefix: /api/}}]
    fault:
      delay:
        percentage: {value: 100}
        fixedDelay: 3s
    route:
    - destination: {host: backend, port: {number: 5000}}
  - match: [{uri: {prefix: /health}}]
    route:
    - destination: {host: backend, port: {number: 5000}}
  - route:
    - destination: {host: frontend, port: {number: 80}}
YAML
sleep 5

phase "WITH FAULT INJECTION (3s delay)" 180

echo "  ROLLING BACK"
cat <<YAML | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: demo-vs
  namespace: ${NAMESPACE}
spec:
  hosts: ['*']
  gateways: ['istio-system/demo-gateway']
  http:
  - match: [{uri: {prefix: /api/}}]
    route:
    - destination: {host: backend, port: {number: 5000}}
  - match: [{uri: {prefix: /health}}]
    route:
    - destination: {host: backend, port: {number: 5000}}
  - route:
    - destination: {host: frontend, port: {number: 80}}
YAML
sleep 5
phase "RECOVERY" 30
echo "Scenario 1 complete"

# =============================================================================
# Scenario 2: Harbor core down
# =============================================================================
echo ""
echo ""
echo ""
echo ""

phase "BASELINE (normal)" 30

echo "  INJECTING HTTP 500 on harbor-nginx (EnvoyFilter)"
kubectl apply -f - <<YAML
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: harbor-nginx-abort
  namespace: ${HARBOR_NS}
spec:
  workloadSelector:
    labels:
      component: nginx
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.fault
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.fault.v3.HTTPFault
          abort:
            http_status: 500
            percentage:
              numerator: 100
              denominator: HUNDRED
YAML
sleep 5

phase "WITH HTTP 500" 180

echo "  ROLLING BACK"
kubectl delete envoyfilter harbor-nginx-abort -n "${HARBOR_NS}" --ignore-not-found 2>/dev/null
sleep 5
phase "RECOVERY" 30
echo "Scenario 2 complete"

# =============================================================================
# Scenario 3: DB Latency (2000ms)
# =============================================================================
echo ""
echo ""
echo ""
echo ""

phase "BASELINE (normal)" 30

echo "  INJECTING 2000ms DB delay <<<"
kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS=2000
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s 2>/dev/null
sleep 5

phase "WITH DB DELAY (2000ms)" 180

echo "  ROLLING BACK <<<"
kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS=0
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s 2>/dev/null
sleep 5
phase "RECOVERY" 30
echo "Scenario 3 complete"

# =============================================================================
# Scenario 4: Network Partition (backend cannot reach DB)
# =============================================================================
echo ""
echo ""
echo ""
echo ""
echo ""

phase "BASELINE (normal)" 30

echo "  BLOCKING backend→DB traffic <<<"
cat <<YAML | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-backend-to-db
  namespace: ${NAMESPACE}
spec:
  selector:
    matchLabels:
      app: db
  action: DENY
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/${NAMESPACE}/sa/default"]
    to:
    - operation:
        ports: ["5432"]
YAML
sleep 5

phase "WITH NETWORK PARTITION" 180

echo "  RESTORING connection <<<"
kubectl delete authorizationpolicy deny-backend-to-db -n "${NAMESPACE}" --ignore-not-found 2>/dev/null
sleep 5
phase "RECOVERY" 30
echo "Scenario 4 complete"

# =============================================================================
echo ""
echo ""
echo ""
echo ""
echo ""
echo "Check Grafana → Chaos Engineering Demo for the full picture."
echo "Each scenario should show a clear spike/dip during the fault period."
