#!/usr/bin/env bash
# lib/setup-dashboard.sh — Installs ClawMetry observability dashboard for OpenClaw.
# Provides metrics, logs, and health monitoring via a local web UI.
set -euo pipefail

setup_dashboard() {
    log_info "Setting up ClawMetry observability dashboard..."
    hr

    # ── Check dependencies ───────────────────────────────────────────────────
    if ! check_command python3; then
        log_error "python3 is required for ClawMetry but was not found."
        log_info "Install Python 3 and re-run this step."
        return 1
    fi

    if ! check_command pip3 && ! python3 -m pip --version &>/dev/null; then
        log_error "pip3 is required for ClawMetry but was not found."
        log_info "Install pip (e.g. 'sudo apt-get install python3-pip') and re-run."
        return 1
    fi

    # ── Install ClawMetry ────────────────────────────────────────────────────
    local install_ok=false

    log_info "Installing ClawMetry via pip..."
    if (pip3 install clawmetry) >> "${CLAWSPARK_LOG}" 2>&1; then
        install_ok=true
        log_success "ClawMetry installed via pip."
    elif (pip3 install --user clawmetry) >> "${CLAWSPARK_LOG}" 2>&1; then
        install_ok=true
        log_success "ClawMetry installed via pip (--user)."
    else
        log_warn "pip3 install clawmetry failed — falling back to git clone."

        # ── Fallback: clone from GitHub ──────────────────────────────────
        local clone_dir="${CLAWSPARK_DIR}/clawmetry"
        if [[ -d "${clone_dir}" ]]; then
            log_info "Existing clone found at ${clone_dir} — pulling latest..."
            (cd "${clone_dir}" && git pull) >> "${CLAWSPARK_LOG}" 2>&1 || true
        else
            log_info "Cloning ClawMetry from GitHub..."
            (git clone https://github.com/vivekchand/clawmetry.git "${clone_dir}") \
                >> "${CLAWSPARK_LOG}" 2>&1 &
            spinner $! "Cloning clawmetry..."
        fi

        if [[ -d "${clone_dir}" ]]; then
            log_info "Installing Flask dependency..."
            (pip3 install flask || pip3 install --user flask) >> "${CLAWSPARK_LOG}" 2>&1 &
            spinner $! "Installing Flask..."
            install_ok=true
            log_success "ClawMetry installed from source."
        else
            log_error "Failed to clone ClawMetry. Check ${CLAWSPARK_LOG}."
            return 1
        fi
    fi

    if [[ "${install_ok}" != "true" ]]; then
        log_error "ClawMetry installation failed."
        return 1
    fi

    # ── Configure ClawMetry workspace ────────────────────────────────────────
    local openclaw_dir="${HOME}/.openclaw"
    local clawmetry_config_dir="${CLAWSPARK_DIR}/clawmetry-config"
    mkdir -p "${clawmetry_config_dir}"

    cat > "${clawmetry_config_dir}/config.json" <<CMEOF
{
  "workspace": "${openclaw_dir}",
  "host": "127.0.0.1",
  "port": 8900,
  "log_file": "${CLAWSPARK_DIR}/dashboard.log"
}
CMEOF
    log_info "ClawMetry configured to use OpenClaw workspace at ${openclaw_dir}"

    # ── Start ClawMetry as a background service ──────────────────────────────
    _start_dashboard

    # ── Verify dashboard is accessible ───────────────────────────────────────
    local retries=5
    local dashboard_up=false
    while (( retries > 0 )); do
        if curl -sf --max-time 2 http://127.0.0.1:8900 &>/dev/null; then
            dashboard_up=true
            break
        fi
        sleep 1
        retries=$(( retries - 1 ))
    done

    if [[ "${dashboard_up}" == "true" ]]; then
        log_success "ClawMetry dashboard is running at http://127.0.0.1:8900"
    else
        log_warn "ClawMetry dashboard did not respond — it may still be starting."
        log_info "Check logs at ${CLAWSPARK_DIR}/dashboard.log"
    fi

    # ── Print dashboard URLs ─────────────────────────────────────────────────
    printf '\n'
    print_box \
        "${BOLD}Dashboard URLs${RESET}" \
        "" \
        "ClawMetry (observability):  http://127.0.0.1:8900" \
        "OpenClaw Control UI:        http://127.0.0.1:18789/__openclaw__/canvas/" \
        "" \
        "The Control UI is built into the OpenClaw gateway" \
        "and requires no additional setup."
    printf '\n'

    log_success "Dashboard setup complete."
}

# ── Internal helpers ─────────────────────────────────────────────────────────

_start_dashboard() {
    local dashboard_log="${CLAWSPARK_DIR}/dashboard.log"
    local dashboard_pid_file="${CLAWSPARK_DIR}/dashboard.pid"

    # Kill existing dashboard if running
    if [[ -f "${dashboard_pid_file}" ]]; then
        local old_pid
        old_pid=$(cat "${dashboard_pid_file}")
        if kill -0 "${old_pid}" 2>/dev/null; then
            log_info "Stopping existing dashboard (PID ${old_pid})..."
            kill "${old_pid}" 2>/dev/null || true
            sleep 1
        fi
    fi

    log_info "Starting ClawMetry dashboard..."
    nohup python3 -m clawmetry --port 8900 --host 127.0.0.1 > "${dashboard_log}" 2>&1 &
    local dash_pid=$!
    echo "${dash_pid}" > "${dashboard_pid_file}"

    sleep 2
    if kill -0 "${dash_pid}" 2>/dev/null; then
        log_success "ClawMetry running (PID ${dash_pid}). Logs: ${dashboard_log}"
    else
        log_warn "ClawMetry process exited unexpectedly. Check ${dashboard_log}."
    fi
}
