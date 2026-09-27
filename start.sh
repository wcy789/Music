#!/usr/bin/env bash
# music-dl 启动脚本（幂等，postCreate / postStart 都会调用）
set -euo pipefail

INSTALL_DIR="$HOME/music-dl"
PORT="${PORT:-8080}"
BASE_PATH="/music"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 1) 没有可执行文件就下载最新 Release
if [ ! -x "$INSTALL_DIR/music-dl" ]; then
  echo "==> 正在下载 music-dl ..."
  TAG="$(curl -fsSL https://api.github.com/repos/guohuiyuan/go-music-dl/releases/latest \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4)"
  echo "    最新版本: ${TAG}"
  curl -fL --retry 5 --retry-all-errors \
    -o "$INSTALL_DIR/music-dl.tar.gz" \
    "https://github.com/guohuiyuan/go-music-dl/releases/download/${TAG}/go-music-dl_linux_amd64.tar.gz"
  tar -xzf "$INSTALL_DIR/music-dl.tar.gz" -C "$INSTALL_DIR" music-dl
  chmod +x "$INSTALL_DIR/music-dl"
  rm -f "$INSTALL_DIR/music-dl.tar.gz"
  echo "    下载完成"
else
  echo "==> 已存在 music-dl，跳过下载"
fi

# 2) 没在跑就启动（nohup 保证脚本退出后进程存活）
if pgrep -f "$INSTALL_DIR/music-dl web" >/dev/null 2>&1; then
  echo "==> music-dl 已在运行"
else
  echo "==> 启动服务，端口 ${PORT} ..."
  nohup "$INSTALL_DIR/music-dl" web --port "$PORT" --no-browser \
    > "$INSTALL_DIR/server.log" 2>&1 &
fi

# 3) 等健康检查通过
for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${PORT}${BASE_PATH}/healthz" >/dev/null 2>&1; then
    echo "==> 服务已就绪"
    echo "    本机地址: http://127.0.0.1:${PORT}${BASE_PATH}/"
    echo "    访问时请在 Codespaces 端口面板把 ${PORT} 的可见性设为 Public（或保持 Private 并用同一 GitHub 账号登录）"
    exit 0
  fi
  sleep 1
done

echo "!! 服务疑似未启动，日志末尾："
tail -n 30 "$INSTALL_DIR/server.log" || true
exit 1
