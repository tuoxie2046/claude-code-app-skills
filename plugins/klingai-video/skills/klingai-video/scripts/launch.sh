#!/bin/bash
# 启动“自动化专用”Chromium：独立 profile + 远程调试端口 9222
# 不会影响你平时用的 Google Chrome。
DIR="$HOME/klingai-automation"
# 自动探测 Chrome for Testing 可执行（不写死版本目录）
BIN=$(ls "$DIR"/browser/chrome/*/chrome-mac-arm64/"Google Chrome for Testing.app"/Contents/MacOS/"Google Chrome for Testing" 2>/dev/null | sort -V | tail -1)
PROFILE="$DIR/profile"

if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
  echo "❌ 找不到 Chrome for Testing，请重新下载: npx @puppeteer/browsers install chrome@stable --path \"$DIR/browser\""
  exit 1
fi

# 若已在运行（端口已监听）就不重复启动
if curl -s --max-time 1 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
  echo "已在运行：CDP endpoint http://127.0.0.1:9222 可用"
  exit 0
fi

"$BIN" \
  --remote-debugging-port=9222 \
  --user-data-dir="$PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  "https://klingai.com/app/video/new?ac=1" \
  >/dev/null 2>&1 &

echo "已启动自动化专用 Chromium (PID $!)。等待 CDP 就绪..."
for i in $(seq 1 20); do
  if curl -s --max-time 1 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
    echo "✅ CDP 就绪：http://127.0.0.1:9222"
    exit 0
  fi
  sleep 0.5
done
echo "⚠️ 等待超时，请检查窗口是否已弹出"
