#!/usr/bin/env bash
# health_check.sh — Disk, Memory, Docker check with timestamped log
# Exit 0=healthy | 1=disk critical (>80%) | 2=warning

set -euo pipefail

DISK_THRESHOLD=80
MEMORY_THRESHOLD=90
LOG_DIR="/var/log/health_check"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
EXIT_CODE=0

# Setup log dir (fallback to /tmp if not root)
mkdir -p "${LOG_DIR}" 2>/dev/null || { LOG_DIR="/tmp/health_check"; mkdir -p "${LOG_DIR}"; }
LOG_FILE="${LOG_DIR}/${TIMESTAMP}.log"

# Colors (only for interactive terminals)
[ -t 1 ] && { RED='\033[0;31m'; YLW='\033[1;33m'; GRN='\033[0;32m'; BLU='\033[0;34m'; RST='\033[0m'; } \
          || { RED=''; YLW=''; GRN=''; BLU=''; RST=''; }

log() {
  local level="$1" msg="$2"
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}"
  echo "${line}" >> "${LOG_FILE}"
  case "${level}" in
    CRITICAL) echo -e "${RED}${line}${RST}" ;;
    WARNING)  echo -e "${YLW}${line}${RST}" ;;
    OK)       echo -e "${GRN}${line}${RST}" ;;
    *)        echo -e "${BLU}${line}${RST}" ;;
  esac
}

# ── 1. Disk Usage ──────────────────────────────────────────────────────────
log INFO "=== DISK USAGE (threshold: ${DISK_THRESHOLD}%) ==="
while IFS= read -r line; do
  usage=$(echo "${line}" | awk '{print $5}' | tr -d '%')
  mount=$(echo "${line}" | awk '{print $6}')
  [[ "${usage}" =~ ^[0-9]+$ ]] || continue
  msg="Disk ${mount}: ${usage}% used"
  if   [ "${usage}" -ge "${DISK_THRESHOLD}" ]; then log CRITICAL "${msg} — EXCEEDS THRESHOLD"; EXIT_CODE=1
  elif [ "${usage}" -ge $(( DISK_THRESHOLD - 10 )) ]; then log WARNING  "${msg} — approaching threshold"
  else log OK "${msg}"; fi
done < <(df -h --output=source,size,used,avail,pcent,target \
           --exclude-type=tmpfs --exclude-type=devtmpfs \
           --exclude-type=overlay --exclude-type=squashfs 2>/dev/null | tail -n +2)

# ── 2. Memory Usage ────────────────────────────────────────────────────────
log INFO "=== MEMORY USAGE (threshold: ${MEMORY_THRESHOLD}%) ==="
if [ -f /proc/meminfo ]; then
  mem_total=$(grep '^MemTotal:'     /proc/meminfo | awk '{print $2}')
  mem_avail=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')
  mem_used=$(( mem_total - mem_avail ))
  mem_pct=$(( mem_used * 100 / mem_total ))
  msg="Memory: ${mem_pct}% used | $(( mem_used/1024 ))MB / $(( mem_total/1024 ))MB total"
  if [ "${mem_pct}" -ge "${MEMORY_THRESHOLD}" ]; then
    log WARNING "${msg} — EXCEEDS ${MEMORY_THRESHOLD}% threshold"
    [ "${EXIT_CODE}" -eq 0 ] && EXIT_CODE=2
  else
    log OK "${msg}"
  fi
else
  log WARNING "Cannot read /proc/meminfo"
  [ "${EXIT_CODE}" -eq 0 ] && EXIT_CODE=2
fi

# ── 3. Docker Service ──────────────────────────────────────────────────────
log INFO "=== DOCKER SERVICE ==="
if ! command -v docker &>/dev/null; then
  log WARNING "Docker is not installed"
  [ "${EXIT_CODE}" -eq 0 ] && EXIT_CODE=2
else
  # Check systemd status
  if command -v systemctl &>/dev/null; then
    status=$(systemctl is-active docker 2>/dev/null || echo "unknown")
    [ "${status}" = "active" ] && log OK "Docker systemd service: ${status}" \
                                || log WARNING "Docker systemd service: ${status}"
  fi
  # Check daemon socket
  if docker info &>/dev/null 2>&1; then
    running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    total=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
    log OK "Docker daemon responsive | running: ${running} | total: ${total}"
    unhealthy=$(docker ps --filter health=unhealthy -q 2>/dev/null | wc -l | tr -d ' ')
    [ "${unhealthy}" -gt 0 ] && { log WARNING "${unhealthy} unhealthy container(s)"; [ "${EXIT_CODE}" -eq 0 ] && EXIT_CODE=2; }
  else
    log WARNING "Docker daemon not responsive"
    [ "${EXIT_CODE}" -eq 0 ] && EXIT_CODE=2
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────
log INFO "=== SUMMARY ==="
log INFO "Host: $(hostname) | Log: ${LOG_FILE}"
case "${EXIT_CODE}" in
  0) log OK       "Status: HEALTHY — all checks passed" ;;
  1) log CRITICAL "Status: CRITICAL — disk exceeds ${DISK_THRESHOLD}%" ;;
  2) log WARNING  "Status: WARNING — one or more checks failed" ;;
esac

# Cleanup logs older than 30 days
find "${LOG_DIR}" -name "*.log" -mtime +30 -delete 2>/dev/null || true

exit "${EXIT_CODE}"
