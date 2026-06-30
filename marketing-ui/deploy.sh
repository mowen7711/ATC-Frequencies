#!/usr/bin/env bash
# ATC Frequencies marketing UI — deploy from Mac to 4t-tech-ubnt-01
# Run from the repo root: bash marketing-ui/deploy.sh
set -euo pipefail

SERVER="root@100.103.65.20"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no"
RSYNC="rsync -avz -e \"ssh -i $SSH_KEY -o StrictHostKeyChecking=no\""
REMOTE_APP="/opt/atc-marketing-ui"
REMOTE_DOCS="/opt/atc-marketing-ui/marketing"
SERVICE="atc-marketing-ui"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Installing Node.js 20 (if needed)"
$SSH "$SERVER" "
  if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
  fi
  echo \"Node: \$(node --version)  npm: \$(npm --version)\"
"

echo "==> Creating remote directories"
$SSH "$SERVER" "mkdir -p $REMOTE_APP/public $REMOTE_DOCS"

echo "==> Syncing app files"
rsync -avz --delete \
  -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
  --exclude node_modules \
  --exclude deploy.sh \
  --exclude .gitignore \
  "$REPO_ROOT/marketing-ui/" "$SERVER:$REMOTE_APP/"

echo "==> Syncing marketing drafts"
rsync -avz \
  -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
  "$REPO_ROOT/marketing/" "$SERVER:$REMOTE_DOCS/"

echo "==> Installing npm dependencies on server"
$SSH "$SERVER" "cd $REMOTE_APP && npm install --omit=dev"

echo "==> Writing systemd service"
NODE_BIN=$($SSH "$SERVER" "which node")
$SSH "$SERVER" "cat > /etc/systemd/system/${SERVICE}.service << 'EOF'
[Unit]
Description=ATC Frequencies Marketing UI
After=network.target tailscaled.service

[Service]
Type=simple
User=root
WorkingDirectory=$REMOTE_APP
ExecStart=$NODE_BIN $REMOTE_APP/server.js
Restart=on-failure
RestartSec=5
Environment=PORT=3000
Environment=BIND_HOST=127.0.0.1
Environment=MARKETING_DOCS_PATH=$REMOTE_DOCS

[Install]
WantedBy=multi-user.target
EOF"

echo "==> Enabling and starting service"
$SSH "$SERVER" "
  systemctl daemon-reload
  systemctl enable $SERVICE
  systemctl restart $SERVICE
  sleep 2
  systemctl status $SERVICE --no-pager
"

echo "==> Installing nginx config"
rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
  "$REPO_ROOT/marketing-ui/nginx.conf" \
  "$SERVER:/etc/nginx/sites-available/$SERVICE"
$SSH "$SERVER" "
  ln -sf /etc/nginx/sites-available/$SERVICE /etc/nginx/sites-enabled/$SERVICE
  nginx -t && systemctl reload nginx
"

echo ""
echo "Done. Marketing UI: http://100.103.65.20:8090 (Tailscale only)"
