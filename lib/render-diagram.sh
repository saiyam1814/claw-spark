#!/usr/bin/env bash
# render-diagram.sh -- Renders Mermaid diagram to PNG via Kroki API
# Deployed to ~/workspace/ by clawspark installer.
#
# Usage:
#   echo "graph TD; A-->B" | render-diagram.sh [output-name]
#   render-diagram.sh [output-name] < file.mmd
#
# Output: Prints the absolute path to the rendered PNG on stdout.
# The PNG is saved to /tmp/openclaw/ which is in OpenClaw's allowed
# media directory list, so the agent can send it via WhatsApp/Telegram.
set -euo pipefail

OUTPUT_NAME="${1:-diagram-$(date +%s)}"
OUTPUT_DIR="/tmp/openclaw"
mkdir -p "${OUTPUT_DIR}"

# Read mermaid code from stdin
MERMAID_CODE=$(cat)

if [ -z "${MERMAID_CODE}" ]; then
    echo "Error: No mermaid code provided on stdin" >&2
    echo "Usage: echo 'graph TD; A-->B' | render-diagram.sh [name]" >&2
    exit 1
fi

# Write to temp file
MMD_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}.mmd"
printf '%s\n' "${MERMAID_CODE}" > "${MMD_FILE}"

# Render via Kroki API (public, free, no auth needed)
PNG_FILE="${OUTPUT_DIR}/${OUTPUT_NAME}.png"
HTTP_CODE=$(curl -sS -w '%{http_code}' -X POST https://kroki.io/mermaid/png \
    -H 'Content-Type: text/plain' \
    --data-binary @"${MMD_FILE}" \
    -o "${PNG_FILE}" 2>/dev/null || echo "000")

if [ "${HTTP_CODE}" = "200" ] && [ -s "${PNG_FILE}" ]; then
    # Success -- print the path for the agent to use
    echo "${PNG_FILE}"
else
    # Clean up failed output
    rm -f "${PNG_FILE}"
    echo "Error: Kroki API returned HTTP ${HTTP_CODE}" >&2
    echo "Mermaid code might have syntax errors. Check the diagram syntax." >&2
    exit 1
fi
