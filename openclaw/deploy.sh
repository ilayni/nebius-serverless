#!/usr/bin/env bash
set -e

USE_PERSISTENCE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --persistent|-p) USE_PERSISTENCE=true; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# 0. Check prerequisites
if ! command -v nebius &> /dev/null; then
    echo "Error: nebius CLI is not found in PATH."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it (e.g., brew install jq)."
    exit 1
fi

if ! command -v cloudflared &> /dev/null; then
    echo "Warning: cloudflared is not installed. You will need it to access the UI (brew install cloudflared)."
fi

if [ -z "$NEBIUS_API_KEY" ]; then
    echo "Error: NEBIUS_API_KEY is not set in .env or environment."
    exit 1
fi

# 1. Set up variables
if [ -z "$AUTH_TOKEN" ]; then
    export AUTH_TOKEN=$(openssl rand -hex 32)
    echo "AUTH_TOKEN=\"$AUTH_TOKEN\"" >> .env
    echo "Generated new AUTH_TOKEN and saved it to .env (do not commit this value)."
else
    echo "Found existing AUTH_TOKEN in environment or .env."
fi

echo "Fetching subnet ID..."
export SUBNET_ID=$(nebius vpc subnet list --format jsonpath='{.items[0].metadata.id}')

if [ "$USE_PERSISTENCE" = true ]; then
    if [ -z "$SHARED_FS_ID" ]; then
        echo "Creating a new Nebius Shared Filesystem..."
        # Note: --size defaults to 100GiB usually or is omitted unless strictly required.
        export SHARED_FS_ID=$(nebius vpc shared-filesystem create --name openclaw-data --subnet-id "$SUBNET_ID" --format json | jq -r '.metadata.id')
        echo "SHARED_FS_ID=\"$SHARED_FS_ID\"" >> .env
        echo "Saved SHARED_FS_ID to .env"
    else
        echo "Found existing SHARED_FS_ID in .env: $SHARED_FS_ID"
    fi
fi

# 2. Generate the OpenClaw config
CHANNELS_JSON=""
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  DM_POLICY="open"
  ALLOW_FROM_JSON=""

  if [ -n "$TELEGRAM_ALLOW_ID" ]; then
    DM_POLICY="allowlist"
    ALLOW_FROM_JSON="\"allowFrom\": [${TELEGRAM_ALLOW_ID}],"
  fi

  CHANNELS_JSON=$(cat <<EOF
  ,
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "${DM_POLICY}",
      ${ALLOW_FROM_JSON}
      "botToken": "${TELEGRAM_BOT_TOKEN}"
    }
  }
EOF
)
fi

OPENCLAW_CONFIG=$(cat <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true,
      "dangerouslyDisableDeviceAuth": true
    },
    "auth": {
      "mode": "token",
      "token": "${AUTH_TOKEN}"
    },
    "http": {
      "endpoints": {
        "chatCompletions": {
          "enabled": true
        }
      }
    }
  },
  "models": {
    "providers": {
      "tokenfactory": {
        "baseUrl": "https://api.tokenfactory.us-central1.nebius.com/v1",
        "apiKey": "${NEBIUS_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "zai-org/GLM-5",
            "name": "GLM-5"
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "tokenfactory/zai-org/GLM-5"
      }
    }
  }
  ${CHANNELS_JSON}
}
EOF
)

# Use portable base64 encoding (works on macOS and Linux)
OPENCLAW_CONFIG_B64=$(echo "$OPENCLAW_CONFIG" | base64 | tr -d '\n' | tr -d '\r')

# 3. Create the endpoint
echo "Creating Nebius Serverless CPU Endpoint..."

ENDPOINT_ARGS=(
  --name demo-openclaw-cpu
  --image ghcr.io/openclaw/openclaw:latest
  --container-command bash
  --platform cpu-d3
  --preset 8vcpu-32gb
  --public
  --container-port 18789
  --subnet-id "$SUBNET_ID"
  --env "OPENCLAW_GATEWAY_TOKEN=$AUTH_TOKEN"
)

STARTUP_CMD="mkdir -p /home/node/.openclaw && "
STARTUP_CMD+="( [ -f /home/node/.openclaw/openclaw.json ] || echo \${OPENCLAW_CONFIG_B64} | base64 -d > /home/node/.openclaw/openclaw.json )"
STARTUP_CMD+=" && cd /app && node dist/index.js gateway run --port 18789 --bind lan --allow-unconfigured"

ENDPOINT_ARGS+=(--args "-lc '\${STARTUP_CMD}'")

if [ "$USE_PERSISTENCE" = true ]; then
  ENDPOINT_ARGS+=(--mount-file-system "id=\${SHARED_FS_ID},mount-path=/home/node/.openclaw")
fi

nebius ai endpoint create "\${ENDPOINT_ARGS[@]}"

# 4. Wait for Running status
echo "Waiting for endpoint to become RUNNING..."
while true; do
    STATE=$(nebius ai endpoint get-by-name --name demo-openclaw-cpu --format json | jq -r '.status.state')
    
    if [ "$STATE" == "RUNNING" ]; then
        echo "Endpoint is now RUNNING!"
        break
    elif [ "$STATE" == "FAILED" ] || [ "$STATE" == "ERROR" ]; then
        echo "Endpoint creation failed. Current state: $STATE"
        exit 1
    fi
    echo "Current state: $STATE... waiting 10 seconds."
    sleep 10
done

# 5. Get the endpoint IP
export CPU_IP=$(nebius ai endpoint get-by-name --name demo-openclaw-cpu --format json | jq -r '.status.public_endpoints[0]')
echo "Endpoint IP: $CPU_IP"

echo "====================================================="
echo "Deployment successful!"
echo "Your API URL: http://$CPU_IP/v1/chat/completions"
echo ""
echo "To access the UI, run the following command in another terminal:"
echo "cloudflared tunnel --url http://$CPU_IP"
echo ""
echo "Then open the displayed Cloudflare URL in your browser."
echo "Use the wss:// representation of the url and paste your AUTH_TOKEN (check .env)."
echo "====================================================="
