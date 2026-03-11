#!/usr/bin/env bash
# lib/setup-tailscale.sh — Optional Tailscale setup for secure remote access
# to OpenClaw and ClawMetry from anywhere on your Tailnet.
set -euo pipefail

setup_tailscale() {
    log_info "Tailscale setup (optional)..."
    hr

    # ── Ask if user wants Tailscale ──────────────────────────────────────────
    if ! prompt_yn "Would you like to set up Tailscale for secure remote access?" "n"; then
        log_info "Tailscale setup skipped."
        return 0
    fi

    # ── Install Tailscale if not present ─────────────────────────────────────
    if check_command tailscale; then
        log_success "Tailscale is already installed."
    else
        log_info "Installing Tailscale..."
        (curl -fsSL https://tailscale.com/install.sh | sh) >> "${CLAWSPARK_LOG}" 2>&1 &
        spinner $! "Installing Tailscale..."

        if ! check_command tailscale; then
            log_error "Tailscale installation failed. Check ${CLAWSPARK_LOG}."
            return 1
        fi
        log_success "Tailscale installed."
    fi

    # ── Connect to Tailnet ───────────────────────────────────────────────────
    if tailscale status &>/dev/null; then
        log_success "Tailscale is connected."
    else
        log_info "Tailscale is not connected. Starting Tailscale..."
        sudo tailscale up 2>&1 | tee -a "${CLAWSPARK_LOG}" || {
            log_error "Failed to connect Tailscale. Run 'sudo tailscale up' manually."
            return 1
        }

        if tailscale status &>/dev/null; then
            log_success "Tailscale connected."
        else
            log_error "Tailscale did not connect. Check 'tailscale status' for details."
            return 1
        fi
    fi

    # ── Get machine name for display ─────────────────────────────────────────
    local machine_name
    machine_name=$(tailscale status --self=true --peers=false 2>/dev/null \
        | awk '{print $2}' | head -1 || echo "your-machine")

    local tailnet_name
    tailnet_name=$(tailscale status --json 2>/dev/null \
        | grep -o '"MagicDNSSuffix":"[^"]*"' | cut -d'"' -f4 || echo "tail-net-name")

    # ── Restart gateway with Tailscale ───────────────────────────────────────
    log_info "Configuring OpenClaw gateway for Tailscale..."

    local gateway_pid_file="${CLAWSPARK_DIR}/gateway.pid"
    local gateway_log="${CLAWSPARK_DIR}/gateway.log"

    # Stop existing gateway
    if [[ -f "${gateway_pid_file}" ]]; then
        local old_pid
        old_pid=$(cat "${gateway_pid_file}")
        if kill -0 "${old_pid}" 2>/dev/null; then
            log_info "Stopping existing gateway (PID ${old_pid})..."
            kill "${old_pid}" 2>/dev/null || true
            sleep 1
        fi
    fi

    # Source Ollama provider credentials
    local env_file="${HOME}/.openclaw/gateway.env"
    [[ -f "${env_file}" ]] && set -a && source "${env_file}" && set +a

    # Restart with --tailscale flag
    nohup openclaw gateway run --tailscale serve > "${gateway_log}" 2>&1 &
    local gw_pid=$!
    echo "${gw_pid}" > "${gateway_pid_file}"

    sleep 2
    if kill -0 "${gw_pid}" 2>/dev/null; then
        log_success "Gateway restarted with Tailscale (PID ${gw_pid})."
    else
        log_warn "Gateway process exited — it may need manual restart."
        log_info "Try: openclaw gateway run --tailscale serve"
    fi

    # ── Print access information ─────────────────────────────────────────────
    printf '\n'
    print_box \
        "${BOLD}Tailscale Remote Access${RESET}" \
        "" \
        "OpenClaw gateway:" \
        "  https://${machine_name}.${tailnet_name}:18789" \
        "" \
        "To also expose the ClawMetry dashboard:" \
        "  tailscale serve 8900" \
        "" \
        "Access from any device on your Tailnet." \
        "Traffic is encrypted end-to-end via WireGuard."
    printf '\n'

    log_info "You can now access your AI assistant from any device on your Tailnet"
    log_info "at https://${machine_name}.${tailnet_name}:18789"
    log_info "To expose the ClawMetry dashboard remotely, run: tailscale serve 8900"

    log_success "Tailscale setup complete."
}
