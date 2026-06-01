# OpenClaw Setup Plan

## Objective
Establish a deployment setup for OpenClaw as a serverless CPU endpoint on Nebius AI, connected to TokenFactory model inference, according to the provided tutorial.

## Steps Executed

1.  **Analyze Tutorial Requirements**
    *   Verified the necessary prerequisites (`nebius`, `jq`, `cloudflared`, and an API key).
    *   Determined the core commands needed to fetch VPC subnet IDs, generate an auth token, create the endpoint configuration, and deploy the endpoint via the Nebius CLI.

2.  **Create `.env` File Template**
    *   Added `NEBIUS_API_KEY` placeholder.
    *   Added commented-out `AUTH_TOKEN`, allowing the deployment script to generate safely if blank.

3.  **Implement `deploy.sh`**
    *   Automated checking for binary requirements.
    *   Incorporated sourcing `.env`.
    *   Obfuscated output logging so `AUTH_TOKEN` is not printed in plaintext to the console. Auto-generation logic appends the token secretly directly to the `.env` file if it's currently unconfigured.
    *   Executed the `nebius ai endpoint create` parameters seamlessly.
    *   Added polling to wait for the endpoint state to switch to `RUNNING`.
    *   Added instructional output indicating the Cloudflare deployment parameters.

4.  **Implement `cleanup.sh`**
    *   Automated fetching the endpoint ID by its name (`demo-openclaw-cpu`).
    *   Automated issuing the API call to delete the endpoint (`nebius ai endpoint delete`).

5.  **Create `README.md`**
    *   Formally documented the function of all scripts.
    *   Outlined required commands to deploy securely using Cloudflare tunnels.

6.  **Create `.gitignore`**
    *   Blocked `.env` from accidental commits.
