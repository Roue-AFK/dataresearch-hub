#!/bin/bash

# TAPD Open API（外网 SaaS / tapd-apikey）— 经 agent-gateway 代理
#
# 用法: ./tapd_api.sh <method> <api_path> [query_string]
#
# Gateway: http://tapd-apikey.agent-gateway.auth-proxy.local
# upstream 由 gateway 转发至 api.tapd.cn，Agent 无需感知。

set -e

RED='\033[0;31m'
NC='\033[0m'

CONNECTOR_MODULE="tapd-apikey"
GATEWAY_SUFFIX="agent-gateway.auth-proxy.local"
MAX_RETRIES=3
RETRY_DELAY=2
CONNECT_TIMEOUT=10
MAX_TIME=60

show_usage() {
    cat <<'EOF'
用法: tapd_api.sh <method> <api_path> [query_string]

Connector: tapd-apikey（外网 SaaS）
Gateway:   http://tapd-apikey.agent-gateway.auth-proxy.local

示例:
  tapd_api.sh GET /workspaces/user_participant_projects
  tapd_api.sh GET /bugs 'workspace_id=123&limit=20'
EOF
    exit 1
}

METHOD="${1:-}"
API_PATH="${2:-}"
QUERY="${3:-}"

if [ -z "$METHOD" ] || [ -z "$API_PATH" ]; then
    show_usage
fi

case "$METHOD" in
    GET|POST|PUT|DELETE|PATCH) ;;
    *) echo -e "${RED}不支持的 HTTP 方法: $METHOD${NC}" >&2; exit 1 ;;
esac

[[ "$API_PATH" != /* ]] && API_PATH="/${API_PATH}"

GATEWAY_BASE="${TAPD_GATEWAY_BASE:-http://${CONNECTOR_MODULE}.${GATEWAY_SUFFIX}}"
GATEWAY_BASE="${GATEWAY_BASE%/}"
URL="${GATEWAY_BASE}${API_PATH}"
[ -n "$QUERY" ] && URL="${URL}?${QUERY}"

do_request() {
    local retry=0
    while [ $retry -lt $MAX_RETRIES ]; do
        local resp
        resp=$(curl -s -w "\n%{http_code}" -X "$METHOD" "$URL" \
            -H "Content-Type: application/json" -H "Accept: application/json" \
            --connect-timeout "$CONNECT_TIMEOUT" --max-time "$MAX_TIME" 2>&1) || true
        local code body
        code=$(echo "$resp" | tail -n1)
        body=$(echo "$resp" | sed '$d')
        if [ "$code" = "200" ] || [ "$code" = "201" ]; then
            echo "$body"; return 0
        elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
            echo -e "${RED}授权失败 (HTTP $code) - 请检查 TAPD 连接器授权${NC}" >&2
            echo "$body" >&2; return 1
        elif [ "$code" -ge "500" ] || [ "$code" = "429" ]; then
            retry=$((retry + 1)); [ $retry -lt $MAX_RETRIES ] && sleep $RETRY_DELAY
        else
            echo -e "${RED}请求失败 (HTTP $code): $URL${NC}" >&2
            echo "$body" >&2; return 1
        fi
    done
    echo -e "${RED}请求超时，已重试 $MAX_RETRIES 次${NC}" >&2
    return 1
}

do_request
