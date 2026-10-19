#!/usr/bin/env bash
# 开发环境三服务重启（加载 backend/.env 真实值、剥离系统代理）
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
set -a; . ./.env; set +a
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
for PORT in 7600 7700 7900; do
  PID=$(netstat -ano | grep ":$PORT " | grep -i listen | head -1 | awk '{print $NF}')
  [ -n "$PID" ] && taskkill //F //PID $PID >/dev/null 2>&1
done
sleep 2
cd "$ROOT/app/core/service"  && "$ROOT/bin/core-server.exe"  -c ./configs > "$ROOT/bin/core.log"  2>&1 &
cd "$ROOT/app/admin/service" && "$ROOT/bin/admin-server.exe" -c ./configs > "$ROOT/bin/admin.log" 2>&1 &
cd "$ROOT/app/app/service"   && "$ROOT/bin/app-server.exe"   -c ./configs > "$ROOT/bin/app.log"   2>&1 &
sleep 8
netstat -ano | grep -E ":(7600|7700|7900) " | grep -i listen | wc -l
