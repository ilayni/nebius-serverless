# OpenClaw on Nebius Serverless Setup

This directory contains utility scripts to automate the deployment of [OpenClaw](https://github.com/openclaw/openclaw) as a Nebius Serverless CPU endpoint based on the [serverless-cookbook tutorial](https://github.com/mnrozhkov/serverless-cookbook/tree/main/agents/openclaw). This acts as an AI Gateway connected to Nebius TokenFactory model inference.

## Prerequisites

Before running any scripts, make sure you have:
1. **Nebius CLI** installed and configured.
2. **jq** installed (e.g., `brew install jq`).
3. **cloudflared** installed (e.g., `brew install cloudflared`) - Required to securely access the Web UI.

## Setup Instructions

1. **Configure Environment Variables**:
   Open the `.env` file and insert your Nebius TokenFactory API Key:
   ```bash
   NEBIUS_API_KEY="your-real-key"
   ```
   *Note: If you leave `AUTH_TOKEN` blank, the deploy script will automatically generate a secure 32-byte hex token and save it to `.env`.*

2. **Make Scripts Executable**:
   You need to add execution permissions to the scripts before running them:
   ```bash
   chmod +x deploy.sh cleanup.sh
   ```

3. **Deploy the Gateway**:
   Run the deployment script:
   ```bash
   ./deploy.sh
   ```
   This will:
   - Create a Serverless CPU endpoint on Nebius.
   - Wait for it to become `RUNNING`.
   - Print out the Endpoint's exact public IP.

## Accessing the Web UI

Due to browser WebCrypto constraints, the OpenClaw GUI must be served over HTTPS. Use `cloudflared` to setup a temporary secure tunnel:
```bash
cloudflared tunnel --url http://<YOUR_ENDPOINT_IP>
You can force it to use a more stable TCP (http2) connection by running:
bash
cloudflared tunnel --protocol http2 --url http://89.169.115.108:18789
```
1. Open the resulting `https://...trycloudflare.com` URL in your browser.
2. In the OpenClaw UI, the WebSocket URL should auto-fill with the `wss://` version of that URL.
3. For the **Gateway Token**, use the `AUTH_TOKEN` which the `deploy.sh` script saved in your `.env` file.

## Teardown

To avoid incurring any unnecessary costs when you're finished experimenting, you can quickly destroy the endpoint:
```bash
./cleanup.sh
```

## Debugging

If the gateway seems unresponsive or you are getting "connection refused", it is likely the deployed container has crashed or failed to start. 

**Check Gateway Status:**
You can check the exact state of the container (look for `"state": "FAILED"` inside the `instances` array) by running:
```bash
nebius ai endpoint get-by-name --name demo-openclaw-cpu --format json | jq '.status'
```

**View Logs:**
Sometimes, seeing the actual output from the backend is necessary to figure out what's breaking (like an invalid API key or bad config format).
```bash
nebius ai endpoint logs $(nebius ai endpoint get-by-name --name demo-openclaw-cpu --format json | jq -r '.metadata.id')
```