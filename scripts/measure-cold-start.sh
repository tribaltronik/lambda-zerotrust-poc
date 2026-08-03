#!/usr/bin/env bash
set -euo pipefail

# Measure Lambda cold starts for the zero-trust PoC handlers.
#
# Forces a fresh container for each function by writing a unique COLDSTART_PROBE
# value into its environment (any config change recycles the execution
# environment), then invokes the function N times and parses the Init Duration /
# Duration fields from the CloudWatch Tail logs (REPORT lines).
#
# Works against real AWS (and is harmless against Floci). Requires the AWS CLI.
#
# Usage: ./scripts/measure-cold-start.sh [options]
#   --function <name>   Function to measure (repeatable). Defaults to all
#                       ${PREFIX}-* functions found via aws lambda list-functions.
#   --samples <N>       Invocations per function (default: 5).
#   --prefix <prefix>   Function-name prefix used for auto-discovery (default: lambda-zerotrust-poc).
#   --payload <json>    Invocation payload (default: a GET /items event).
#   --region <region>   AWS region (default: \$AWS_REGION or us-east-1).
#   -h, --help          Show this help and exit.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ANSI colors only when stdout is a TTY.
GREEN=""
YELLOW=""
RED=""
BOLD=""
NC=""
if [ -t 1 ]; then
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    RED=$'\033[0;31m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
fi

echo_ok()  { printf '    %s✓%s %s\n' "$GREEN" "$NC" "$1"; }
echo_warn(){ printf '    %s⚠%s %s\n' "$YELLOW" "$NC" "$1"; }

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
}

# --- CLI parsing ------------------------------------------------------------
FUNCTIONS=()
SAMPLES=5
PREFIX="lambda-zerotrust-poc"
PAYLOAD='{"path":"/items","httpMethod":"GET","headers":{},"body":null}'
REGION="${AWS_REGION:-us-east-1}"

while [ $# -gt 0 ]; do
    case "$1" in
        --function)
            FUNCTIONS+=("${2:?--function requires a name}")
            shift 2
            ;;
        --samples)
            SAMPLES="${2:?--samples requires a number}"
            shift 2
            ;;
        --prefix)
            PREFIX="${2:?--prefix requires a value}"
            shift 2
            ;;
        --payload)
            PAYLOAD="${2:?--payload requires a JSON string}"
            shift 2
            ;;
        --region)
            REGION="${2:?--region requires a value}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$SAMPLES" in
    ''|*[!0-9]*)
        echo "${RED}ERROR:${NC} --samples must be a positive integer (got: $SAMPLES)" >&2
        exit 2
        ;;
esac
[ "$SAMPLES" -gt 0 ] 2>/dev/null || { echo "${RED}ERROR:${NC} --samples must be >= 1" >&2; exit 2; }

if ! command -v aws >/dev/null 2>&1; then
    echo "${RED}ERROR:${NC} AWS CLI not found. Install it from https://aws.amazon.com/cli/ and try again." >&2
    exit 1
fi

# Portable base64 decode (GNU coreutils uses -d, macOS uses -D).
if printf '' | base64 --decode >/dev/null 2>&1; then
    DECODE_CMD=(base64 --decode)
else
    DECODE_CMD=(base64 -D)
fi

# --- Function discovery -----------------------------------------------------
if [ "${#FUNCTIONS[@]}" -eq 0 ]; then
    echo "No --function given; discovering ${PREFIX}-* functions..."
    FUNCTIONS=()
    while IFS= read -r fn; do
        [ -n "$fn" ] && FUNCTIONS+=("$fn")
    done < <(
        aws lambda list-functions --region "$REGION" \
            --query 'Functions[].FunctionName' --output text \
            2>/dev/null | tr '\t' '\n' | grep "^${PREFIX}-" | sort
    )
fi

if [ "${#FUNCTIONS[@]}" -eq 0 ]; then
    echo "${RED}ERROR:${NC} No functions found (prefix '${PREFIX}-'). Pass --function NAME explicitly." >&2
    exit 1
fi

# --- Cold-start forcing -----------------------------------------------------
# Updating the function config (even an env-var change) recycles the execution
# environment, guaranteeing a cold start on the next invoke. The existing
# environment variables are preserved — only COLDSTART_PROBE is set/refreshed.
force_cold_start() {
    local fn="$1"
    local probe="$2"
    local vars

    vars="$(aws lambda get-function-configuration --function-name "$fn" --region "$REGION" \
        --query 'Environment.Variables' --output json 2>/dev/null || true)"

    case "$vars" in
        ''|'null'|'None') vars='{}' ;;
    esac

    # Drop any stale probe from a previous run, then inject a fresh one.
    vars="$(printf '%s' "$vars" | sed 's/,"COLDSTART_PROBE":"[^"]*"//; s/"COLDSTART_PROBE":"[^"]*",//')"
    if [ "$vars" = '{}' ]; then
        vars="{\"COLDSTART_PROBE\":\"$probe\"}"
    else
        vars="$(printf '%s' "$vars" | sed "s/^{/{\"COLDSTART_PROBE\":\"$probe\",/")"
    fi

    aws lambda update-function-configuration --function-name "$fn" --region "$REGION" \
        --environment "{\"Variables\": $vars}" >/dev/null
}

# --- Report parsing ---------------------------------------------------------
# A cold REPORT line looks like:
#   REPORT RequestId: ... Duration: 12.34 ms Billed Duration: 13 ms
#          Memory Size: 256 MB Max Memory Used: 60 MB Init Duration: 400.12 ms
# "Init Duration" only appears on the first (cold) call. It trails "Duration",
# so strip it before extracting the wall-clock duration. Emits "init total"
# on a single line (empty field when absent) for easy `read`.
parse_report() {
    local report="$1"
    local init=""
    local total=""

    init="$(printf '%s' "$report" | sed -n 's/.*Init Duration: \([0-9.]*\) ms.*/\1/p')"
    # Strip "Init Duration" and "Billed Duration" so the only remaining
    # "Duration:" token is the wall-clock duration.
    total="$(printf '%s' "$report" \
        | sed -e 's/Init Duration: [0-9.]* ms//' -e 's/Billed Duration: [0-9.]* ms//' \
        | sed -n 's/.*Duration: \([0-9.]*\) ms.*/\1/p')"

    printf '%s %s\n' "$init" "$total"
}

# --- Aggregation ------------------------------------------------------------
# Reads one number per line on stdin, prints the median.
median_of() {
    sort -n | awk '{ a[NR]=$1 }
        END { if (NR == 0) print "n/a"; else if (NR % 2 == 1) print a[(NR+1)/2]; else print (a[NR/2] + a[NR/2+1]) / 2 }'
}

# Reads one number per line on stdin, prints "min | median | max" (or "n/a").
stats_line() {
    local sorted
    sorted="$(sort -n)"
    [ -z "$sorted" ] && { printf 'n/a'; return; }

    local min max median
    min="$(printf '%s\n' "$sorted" | head -1)"
    max="$(printf '%s\n' "$sorted" | tail -1)"
    median="$(printf '%s\n' "$sorted" | median_of)"
    printf '%.1f | %.1f | %.1f' "$min" "$median" "$max"
}

# --- Measure ----------------------------------------------------------------
echo ""
printf '%sLambda cold-start measurement%s (region %s, %d sample(s)/function)\n' "$BOLD" "$NC" "$REGION" "$SAMPLES"
printf '%-44s %7s %11s %-24s %16s\n' "Function" "Samples" "ColdStarts" "Init ms (min|med|max)" "Duration med"
printf '%s\n' "---------------------------------------------------------------------------------------------------------------------------"

TMPDIR_PROBE="${TMPDIR:-/tmp}/lambda-coldstart.$$"
mkdir -p "$TMPDIR_PROBE"
trap 'rm -rf "$TMPDIR_PROBE"' EXIT

for fn in "${FUNCTIONS[@]}"; do
    printf '\n%s=== %s ===%s\n' "$BOLD" "$fn" "$NC"
    echo "  Forcing a cold start (refreshing COLDSTART_PROBE env)..."
    force_cold_start "$fn" "$(date +%s)"
    echo_ok "cold start forced"

    INIT_MS=()
    TOTAL_MS=()
    cold_count=0

    for i in $(seq 1 "$SAMPLES"); do
        resp_file="$TMPDIR_PROBE/resp.$i"
        log_file="$TMPDIR_PROBE/log.$i"
        out_file="$TMPDIR_PROBE/out.$i"

        if aws lambda invoke --function-name "$fn" --region "$REGION" \
            --cli-binary-format raw-in-base64-out --log-type Tail \
            --payload "$PAYLOAD" --query 'LogResult' --output text \
            "$resp_file" >"$out_file" 2>"$log_file"; then
            LOG_B64="$(tr -d '[:space:]' <"$out_file" || true)"
        else
            LOG_B64=""
        fi

        if [ -z "$LOG_B64" ] || [ "$LOG_B64" = "null" ] || [ "$LOG_B64" = "None" ]; then
            echo_warn "invoke $i returned no log output"
            continue
        fi

        LOGS="$(printf '%s' "$LOG_B64" | "${DECODE_CMD[@]}" 2>/dev/null || true)"
        REPORT="$(printf '%s' "$LOGS" | grep 'REPORT' | tail -1 || true)"

        if [ -z "$REPORT" ]; then
            echo_warn "invoke $i produced no REPORT line"
            continue
        fi

        read -r init_ms total_ms <<EOF
$(parse_report "$REPORT")
EOF

        if [ -n "$total_ms" ]; then
            TOTAL_MS+=("$total_ms")
        fi
        if [ -n "$init_ms" ]; then
            INIT_MS+=("$init_ms")
            cold_count=$((cold_count + 1))
        fi
    done

    init_stats="n/a"
    [ "${#INIT_MS[@]}" -gt 0 ] && init_stats="$(printf '%s\n' "${INIT_MS[@]}" | stats_line)"
    dur_median="n/a"
    [ "${#TOTAL_MS[@]}" -gt 0 ] && dur_median="$(printf '%s\n' "${TOTAL_MS[@]}" | median_of)"

    printf '%-44s %7d %11d %-24s %16s\n' \
        "$fn" "$SAMPLES" "$cold_count" "$init_stats" "$dur_median"
done

echo ""
echo "Done. Expect cold-started ≈ 1/$SAMPLES (only the first invoke after the env change is cold)."
echo "See docs/observability.md for what the numbers mean and how to reduce them."
