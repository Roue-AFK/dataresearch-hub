#!/bin/bash
#
# Automation Task Manager - HTTP API Client
# 用于调用 scheduler API 进行任务管理
#
# 使用方法: ./scheduler-api.sh <action> [options]
# Actions: create | list | get | update | delete
#

set -e

# load_trusted_env
# 幂等地从可信源拉取 env 并 source 到当前 shell。分两步：
#   1. sandbox-proxy 侧车（http://127.0.0.1:49983/envs）：系统级可信 env。
#   2. per-session bot env 文件：session 专属上下文（bot channel、session type）。
# 步 2 在步 1 之后执行，bot env 优先级更高（session 专属覆盖系统默认）。
#
# 行为契约：
#   - 步 1 侧车成功 + 值非空 → export 覆盖当前 shell 同名变量
#   - 步 1 侧车成功 + 值为空 → 跳过（避免空字符串覆盖现有有效 env）
#   - 步 1 侧车失败 / 返回非 JSON / 无 jq → 静默 fallback（不阻断脚本）
#   - 步 2 文件存在且 CODEBUDDY_SESSION_ID 非空 → source（幂等：_ONLY_ONCE）
#
# 已知限制：value 含换行符的场景下 @sh 转义会跨行，无法用 eval 重建。
# 沙箱侧车 env 不会出现换行符值，故不做特殊处理。
load_trusted_env() {
    [ -n "$_CB_TRUSTED_ENV_LOADED" ] && return 0

    # Step 1: sandbox-proxy 侧车 —— 系统级可信 env
    local trusted_env_url="http://127.0.0.1:49983/envs"
    local response

    # --max-time 3: 避免侧车不可用时 hang 住整个脚本
    # -f: 4xx/5xx 视作失败（避免误把错误页当 JSON 解析）
    if response=$(curl -s --max-time 3 -f "$trusted_env_url" 2>/dev/null) && [ -n "$response" ] && command -v jq &> /dev/null; then
        if echo "$response" | jq -e 'type == "object"' >/dev/null 2>&1; then
            # 跳过空值；jq @sh 自动做 shell 转义（value 中的单引号/特殊字符）
            # process substitution 而非 pipe：避免子 shell 导致 export 失效
            while IFS= read -r entry; do
                # entry 格式: KEY=shell-escaped-VALUE（@sh 对空字符串输出 ''）
                case "$entry" in
                    *='') continue ;;
                esac
                # shellcheck disable=SC2086
                eval "export $entry" 2>/dev/null || true
            done < <(echo "$response" | jq -r 'to_entries[] | select(.value != "") | "\(.key)=\(.value | @sh)"' 2>/dev/null)
        fi
    fi

    # Step 2: per-session bot env（CODEBUDDY_SESSION_ID 可能已被步 1 注入）
    if [ -n "$CODEBUDDY_SESSION_ID" ] && [ -f "/tmp/codebuddy_bot_env/${CODEBUDDY_SESSION_ID}.env" ]; then
        # shellcheck disable=SC1090
        source "/tmp/codebuddy_bot_env/${CODEBUDDY_SESSION_ID}.env"
    fi

    _CB_TRUSTED_ENV_LOADED=1
}

# 拉取并 source 侧车 + bot session 的可信 env；侧车不可用时静默 fallback
load_trusted_env

# 防护：自动化调度任务执行期间禁止调用此脚本（避免递归管理任务）
if [ "$CODEBUDDY_SESSION_TYPE" = "automation" ]; then
    echo "ERROR: 当前处于自动化任务执行环境（CODEBUDDY_SESSION_TYPE=automation），禁止管理定时任务" >&2
    exit 1
fi

# 默认配置
DEFAULT_TIMEZONE="Asia/Shanghai"
DEFAULT_TIMEOUT_SEC=300
DEFAULT_RETRY_COUNT=3
DEFAULT_PAGE_SIZE=20

# 打印帮助信息
print_help() {
    cat << 'EOF'
Usage: scheduler-api.sh <action> [options]

Actions:
  create    创建新任务 (必填: --name, --cron, --prompt, --frequency-type)
  list      获取任务列表 (可选: --page, --page-size, --status, --keyword)
  get       获取任务详情 (必填: --id)
  update    更新任务 (必填: --id, 可选: --name, --cron, --prompt, --status 等)
  delete    删除任务 (必填: --id)

Frequency Types:
  daily     每天执行 (每天X点、工作日、周末、每周X)
  interval  按间隔执行 (每X分钟、每X小时)
  once      单次执行 (指定日期时间只执行一次)

Examples:
  scheduler-api.sh create --name "日报提醒" --cron "0 0 21 * * *" --prompt "提醒写日报" --frequency-type daily
  scheduler-api.sh create --name "状态检查" --cron "0 0 * * * *" --prompt "检查服务状态" --frequency-type interval
  scheduler-api.sh list --status 1
  scheduler-api.sh update --id 123 --status 0
  scheduler-api.sh delete --id 123
EOF
}

# 默认 API 地址
DEFAULT_SCHEDULER_API_BASE_URL="http://auth.proxy/codebuddy"

# 检查环境变量，自动从 ACC_PRODUCT_CONFIG_V3 读取
check_env() {
    if [ -z "$SCHEDULER_API_BASE_URL" ]; then
        if [ -n "$ACC_PRODUCT_CONFIG_V3" ] && command -v jq &> /dev/null; then
            SCHEDULER_API_BASE_URL=$(echo "$ACC_PRODUCT_CONFIG_V3" | jq -r '.endpoint // empty')
        fi
    fi

    # 如果仍然为空，使用默认值
    if [ -z "$SCHEDULER_API_BASE_URL" ]; then
        SCHEDULER_API_BASE_URL="$DEFAULT_SCHEDULER_API_BASE_URL"
    fi

    export SCHEDULER_API_BASE_URL
}

# 格式化 JSON 输出
format_json() {
    if command -v jq &> /dev/null; then
        jq '.'
    else
        cat
    fi
}

# 校验 Cron 秒位必须为 0
validate_cron_seconds() {
    local cron_expr="$1"
    local cron_sec
    cron_sec=$(echo "$cron_expr" | awk '{print $1}')
    if [ "$cron_sec" != "0" ]; then
        echo "ERROR: 不允许秒级定时任务，Cron 秒位必须为 0（当前: $cron_sec）" >&2
        exit 1
    fi
}

# 发送 HTTP 请求并处理响应
do_request() {
    local method="$1"
    local url="$2"
    local data="$3"

    local curl_args=(-s -w "\n%{http_code}" -X "$method" -H "Content-Type: application/json")
    # 必须传 X-Enterprise-Id Header
    if [ -n "$X_ENTERPRISE_ID" ]; then
        curl_args+=(-H "X-Enterprise-Id: $X_ENTERPRISE_ID")
    fi
    if [ -n "$data" ]; then
        curl_args+=(-d "$data")
    fi

    local response
    response=$(curl "${curl_args[@]}" "$url")

    local http_code
    http_code=$(echo "$response" | tail -n 1)
    local body
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "$body" | format_json
    else
        echo "FAILED (HTTP $http_code)" >&2
        echo "$body" | format_json >&2
        exit 1
    fi
}

# 创建任务
create_task() {
    local name="" description="" cron_expr="" prompt=""
    local timezone="$DEFAULT_TIMEZONE" timeout_sec="$DEFAULT_TIMEOUT_SEC" retry_count="$DEFAULT_RETRY_COUNT"
    local frequency_type="" effective_start="" effective_end=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            --description) description="$2"; shift 2 ;;
            --cron) cron_expr="$2"; shift 2 ;;
            --prompt) prompt="$2"; shift 2 ;;
            --timezone) timezone="$2"; shift 2 ;;
            --timeout) timeout_sec="$2"; shift 2 ;;
            --retry-count) retry_count="$2"; shift 2 ;;
            --frequency-type) frequency_type="$2"; shift 2 ;;
            --effective-start) effective_start="$2"; shift 2 ;;
            --effective-end) effective_end="$2"; shift 2 ;;
            *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    # 验证必填字段
    [ -z "$name" ] && { echo "ERROR: --name is required" >&2; exit 1; }
    [ -z "$cron_expr" ] && { echo "ERROR: --cron is required" >&2; exit 1; }
    [ -z "$prompt" ] && { echo "ERROR: --prompt is required" >&2; exit 1; }
    [ -z "$frequency_type" ] && { echo "ERROR: --frequency-type is required (daily/interval/once)" >&2; exit 1; }

    # 验证 frequency_type 值
    case "$frequency_type" in
        daily|interval|once) ;;
        *) echo "ERROR: --frequency-type must be one of: daily, interval, once" >&2; exit 1 ;;
    esac

    validate_cron_seconds "$cron_expr"

    # 构建 JSON
    local json_body
    json_body=$(jq -n \
        --arg name "$name" \
        --arg description "$description" \
        --arg cronExpr "$cron_expr" \
        --arg timezone "$timezone" \
        --arg prompt "$prompt" \
        --arg frequencyType "$frequency_type" \
        --argjson timeoutSec "$timeout_sec" \
        --argjson retryCount "$retry_count" \
        '{name: $name, description: $description, cronExpr: $cronExpr, timezone: $timezone, frequencyType: $frequencyType, agentConfig: {prompt: $prompt}, timeoutSec: $timeoutSec, retryCount: $retryCount}')

    [ -n "$effective_start" ] && json_body=$(echo "$json_body" | jq --arg v "$effective_start" '. + {effectiveStart: $v}')
    [ -n "$effective_end" ] && json_body=$(echo "$json_body" | jq --arg v "$effective_end" '. + {effectiveEnd: $v}')

    # ownerType 注入策略（projectId 与 bot channel 互斥，不会同时存在）：
    #   1. X_PROJECT_ID 非空 → ownerType=team + projectId（Teams 协作场景）
    #   2. 否则若 bot channel env 齐全 → ownerType=enterprise + open_sandbox_agent + deliveryConfig
    #   3. 都没有 → 不注入，走 personal 默认行为
    if [ -n "$X_PROJECT_ID" ]; then
        # Teams 项目任务：ownerType=team + projectId（互斥，不附加 bot channel）
        json_body=$(echo "$json_body" | jq \
            --arg projectId "$X_PROJECT_ID" \
            '. + {ownerType: "team", projectId: $projectId}')
    elif [ -n "$CODEBUDDY_BOT_CHANNEL_TYPE" ] && [ -n "$CODEBUDDY_BOT_CHANNEL_ID" ] && [ -n "$CODEBUDDY_BOT_RECIPIENT_ID" ] && [ -n "$CODEBUDDY_BOT_CHANNEL_BINDING_ID" ]; then
        # Bot channel 触发：ownerType=enterprise（保持原有行为）
        json_body=$(echo "$json_body" | jq \
            --arg channelType "$CODEBUDDY_BOT_CHANNEL_TYPE" \
            --arg channelId "$CODEBUDDY_BOT_CHANNEL_ID" \
            --arg recipientId "$CODEBUDDY_BOT_RECIPIENT_ID" \
            --arg bindingId "$CODEBUDDY_BOT_CHANNEL_BINDING_ID" \
            '. + {ownerType: "enterprise", agentType: "open_sandbox_agent", deliveryConfig: {type: "bot_channel", enabled: true, channels: [{type: "bot_channel", enabled: true, options: {channel_type: $channelType, channel_id: $channelId, recipient_id: $recipientId, channel_binding_id: $bindingId}}]}}')
    fi

    do_request POST "$SCHEDULER_API_BASE_URL/v2/as/scheduler/tasks" "$json_body"
}

# 获取任务列表
list_tasks() {
    local page=1 page_size="$DEFAULT_PAGE_SIZE" status="" keyword=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --page) page="$2"; shift 2 ;;
            --page-size) page_size="$2"; shift 2 ;;
            --status) status="$2"; shift 2 ;;
            --keyword) keyword="$2"; shift 2 ;;
            *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    local query="page=$page&pageSize=$page_size"
    [ -n "$status" ] && query="$query&status=$status"
    [ -n "$keyword" ] && query="$query&keyword=$keyword"

    # ownerType 过滤策略（与 create 对齐，projectId 与 bot channel 互斥）：
    #   1. X_PROJECT_ID 非空 → ownerType=team + projectId（仅列出当前项目的团队任务）
    #   2. 否则若 bot channel env 齐全 → ownerType=enterprise + open_sandbox_agent
    #   3. 都没有 → 不附加 ownerType，走后端默认（personal）
    if [ -n "$X_PROJECT_ID" ]; then
        query="$query&ownerType=team&projectId=$X_PROJECT_ID"
    elif [ -n "$CODEBUDDY_BOT_CHANNEL_TYPE" ] && [ -n "$CODEBUDDY_BOT_CHANNEL_ID" ] && [ -n "$CODEBUDDY_BOT_RECIPIENT_ID" ] && [ -n "$CODEBUDDY_BOT_CHANNEL_BINDING_ID" ]; then
        query="$query&ownerType=enterprise&agentType=open_sandbox_agent"
    fi

    do_request GET "$SCHEDULER_API_BASE_URL/v2/as/scheduler/tasks?$query"
}

# 获取任务详情
get_task() {
    local task_id=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --id) task_id="$2"; shift 2 ;;
            *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    [ -z "$task_id" ] && { echo "ERROR: --id is required" >&2; exit 1; }

    do_request GET "$SCHEDULER_API_BASE_URL/v2/as/scheduler/tasks/$task_id"
}

# 更新任务
update_task() {
    local task_id="" name="" description="" cron_expr="" prompt=""
    local timezone="" timeout_sec="" retry_count="" status=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --id) task_id="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --description) description="$2"; shift 2 ;;
            --cron) cron_expr="$2"; shift 2 ;;
            --prompt) prompt="$2"; shift 2 ;;
            --timezone) timezone="$2"; shift 2 ;;
            --timeout) timeout_sec="$2"; shift 2 ;;
            --retry-count) retry_count="$2"; shift 2 ;;
            --status) status="$2"; shift 2 ;;
            *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    [ -z "$task_id" ] && { echo "ERROR: --id is required" >&2; exit 1; }

    [ -n "$cron_expr" ] && validate_cron_seconds "$cron_expr"

    # 构建 JSON（增量添加非空字段）
    local json_body="{}"
    [ -n "$name" ] && json_body=$(echo "$json_body" | jq --arg v "$name" '. + {name: $v}')
    [ -n "$description" ] && json_body=$(echo "$json_body" | jq --arg v "$description" '. + {description: $v}')
    [ -n "$cron_expr" ] && json_body=$(echo "$json_body" | jq --arg v "$cron_expr" '. + {cronExpr: $v}')
    [ -n "$prompt" ] && json_body=$(echo "$json_body" | jq --arg v "$prompt" '. + {agentConfig: {prompt: $v}}')
    [ -n "$timezone" ] && json_body=$(echo "$json_body" | jq --arg v "$timezone" '. + {timezone: $v}')
    [ -n "$timeout_sec" ] && json_body=$(echo "$json_body" | jq --argjson v "$timeout_sec" '. + {timeoutSec: $v}')
    [ -n "$retry_count" ] && json_body=$(echo "$json_body" | jq --argjson v "$retry_count" '. + {retryCount: $v}')
    [ -n "$status" ] && json_body=$(echo "$json_body" | jq --argjson v "$status" '. + {status: $v}')

    if [ "$(echo "$json_body" | jq 'length')" -eq 0 ]; then
        echo "ERROR: No update fields provided" >&2
        exit 1
    fi

    do_request PUT "$SCHEDULER_API_BASE_URL/v2/as/scheduler/tasks/$task_id" "$json_body"
}

# 删除任务
delete_task() {
    local task_id=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --id) task_id="$2"; shift 2 ;;
            *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    [ -z "$task_id" ] && { echo "ERROR: --id is required" >&2; exit 1; }

    do_request DELETE "$SCHEDULER_API_BASE_URL/v2/as/scheduler/tasks/$task_id"
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        print_help
        exit 0
    fi

    local action="$1"
    shift

    case "$action" in
        create) check_env; create_task "$@" ;;
        list)   check_env; list_tasks "$@" ;;
        get)    check_env; get_task "$@" ;;
        update) check_env; update_task "$@" ;;
        delete) check_env; delete_task "$@" ;;
        help|--help|-h) print_help ;;
        *) echo "ERROR: Unknown action: $action" >&2; print_help; exit 1 ;;
    esac
}

main "$@"
