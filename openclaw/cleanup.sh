#!/usr/bin/env bash
set -e

REMOVE_FS=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --rm-fs|--remove-storage) REMOVE_FS=true; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

if ! command -v nebius &> /dev/null; then
    echo "Error: nebius CLI is not found in PATH."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

echo "Fetching endpoint ID..."
ENDPOINT_ID=$(nebius ai endpoint get-by-name --name demo-openclaw-cpu --format json | jq -r '.metadata.id')

if [ -z "$ENDPOINT_ID" ] || [ "$ENDPOINT_ID" == "null" ]; then
    echo "Endpoint 'demo-openclaw-cpu' not found."
    exit 0
fi

echo "Deleting endpoint $ENDPOINT_ID..."
nebius ai endpoint delete "$ENDPOINT_ID"

if [ "$REMOVE_FS" = true ]; then
    if [ -f .env ]; then
        source .env
    fi
    if [ -n "$SHARED_FS_ID" ]; then
        echo "Deleting Shared Filesystem $SHARED_FS_ID..."
        nebius vpc shared-filesystem delete "$SHARED_FS_ID"
        echo "Filesystem deleted."
    else
        echo "No SHARED_FS_ID found in .env, skipping filesystem deletion."
    fi
fi

echo "Cleanup complete."
