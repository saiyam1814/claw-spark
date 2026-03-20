#!/usr/bin/env bash
# lib/setup-systemd.sh -- Creates systemd services for OpenClaw gateway,
# node host, and ClawMetry dashboard so they auto-start on boot.
# Skipped on platforms without systemd (macOS, containers).
set -euo pipefail

setup_systemd_services() {
    # Skip on non-systemd platforms (macOS, Docker, WSL1, etc.)
    if ! check_command systemctl; then
        log_info "systemd not available -- services will use PID-based management."
        return 0
    fi

    # Verify systemd is actually running (not just the binary present)
    if ! systemctl is-system-running &>/dev/null && \
       ! systemctl is-system-running 2>&1 | grep -q 'running\|degraded\|starting'; then
        log_info "systemd not active -- skipping service creation."
        return 0
    fi

    log_info "Creating systemd services for auto-start on boot..."

    local user_name
    user_name=$(whoami)
    local user_home="${HOME}"

    # Find binary paths
    local openclaw_bin
    openclaw_bin=$(command -v openclaw 2>/dev/null || echo "")
    if [[ -z "${openclaw_bin}" ]]; then
        local npm_bin
        npm_bin="$(npm config get prefix 2>/dev/null)/bin"
        [[ -x "${npm_bin}/openclaw" ]] && openclaw_bin="${npm_bin}/openclaw"
    fi

    if [[ -z "${openclaw_bin}" ]]; then
        log_warn "openclaw binary not found -- skipping systemd setup."
        return 0
    fi

    local env_file="${user_home}/.openclaw/gateway.env"

    # Compute a comprehensive PATH for systemd (it starts with minimal PATH)
    # The env file also has PATH, but belt-and-suspenders is safer here
    local npm_prefix_bin
    npm_prefix_bin="$(npm config get prefix 2>/dev/null)/bin"
    local svc_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    [[ -d "${npm_prefix_bin}" ]] && svc_path="${npm_prefix_bin}:${svc_path}"
    [[ -d "${user_home}/.npm-global/bin" ]] && svc_path="${user_home}/.npm-global/bin:${svc_path}"
    [[ -d "/snap/bin" ]] && svc_path="${svc_path}:/snap/bin"

    # ── Gateway service ──────────────────────────────────────────────────────
    sudo tee /etc/systemd/system/clawspark-gateway.service > /dev/null <<GWEOF
[Unit]
Description=clawspark OpenClaw Gateway
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=${user_name}
Environment=HOME=${user_home}
Environment=PATH=${svc_path}
EnvironmentFile=-${env_file}
ExecStart=${openclaw_bin} gateway run --bind loopback
Restart=on-failure
RestartSec=5
StandardOutput=append:${user_home}/.clawspark/gateway.log
StandardError=append:${user_home}/.clawspark/gateway.log

[Install]
WantedBy=multi-user.target
GWEOF
    log_success "Created clawspark-gateway.service"

    # ── Node host service ────────────────────────────────────────────────────
    sudo tee /etc/systemd/system/clawspark-nodehost.service > /dev/null <<NHEOF
[Unit]
Description=clawspark OpenClaw Node Host
After=clawspark-gateway.service
Requires=clawspark-gateway.service

[Service]
Type=simple
User=${user_name}
Environment=HOME=${user_home}
Environment=PATH=${svc_path}
EnvironmentFile=-${env_file}
ExecStartPre=/bin/sleep 3
ExecStart=${openclaw_bin} node run --host 127.0.0.1 --port 18789
Restart=on-failure
RestartSec=5
StandardOutput=append:${user_home}/.clawspark/node.log
StandardError=append:${user_home}/.clawspark/node.log

[Install]
WantedBy=multi-user.target
NHEOF
    log_success "Created clawspark-nodehost.service"

    # ── Dashboard service ────────────────────────────────────────────────────
    local clawmetry_bin=""
    if command -v clawmetry &>/dev/null; then
        clawmetry_bin=$(command -v clawmetry)
    elif [[ -x "${user_home}/.local/bin/clawmetry" ]]; then
        clawmetry_bin="${user_home}/.local/bin/clawmetry"
    fi

    if [[ -n "${clawmetry_bin}" ]]; then
        sudo tee /etc/systemd/system/clawspark-dashboard.service > /dev/null <<DBEOF
[Unit]
Description=clawspark ClawMetry Dashboard
After=network.target

[Service]
Type=simple
User=${user_name}
Environment=HOME=${user_home}
ExecStart=${clawmetry_bin} --port 8900 --host 127.0.0.1
Restart=on-failure
RestartSec=5
StandardOutput=append:${user_home}/.clawspark/dashboard.log
StandardError=append:${user_home}/.clawspark/dashboard.log

[Install]
WantedBy=multi-user.target
DBEOF
        log_success "Created clawspark-dashboard.service"
    else
        log_info "clawmetry binary not found -- dashboard service not created."
    fi

    # ── Enable all services ──────────────────────────────────────────────────
    sudo systemctl daemon-reload

    sudo systemctl enable clawspark-gateway.service >> "${CLAWSPARK_LOG}" 2>&1 || true
    sudo systemctl enable clawspark-nodehost.service >> "${CLAWSPARK_LOG}" 2>&1 || true
    if [[ -n "${clawmetry_bin}" ]]; then
        sudo systemctl enable clawspark-dashboard.service >> "${CLAWSPARK_LOG}" 2>&1 || true
    fi

    log_success "Systemd services enabled -- will auto-start on boot."

    # ── Migrate running nohup processes to systemd ───────────────────────────
    # Stop the nohup-started processes and let systemd take over.
    # This ensures a clean state right now, not just after next reboot.
    log_info "Migrating running services to systemd..."

    # Helper: safely kill a PID from a pid file (validates numeric + process identity)
    _safe_kill_pid() {
        local pid_file="$1" name_hint="$2"
        if [[ -f "${pid_file}" ]]; then
            local pid
            pid=$(cat "${pid_file}" 2>/dev/null || echo "")
            if [[ -n "${pid}" ]] && [[ "${pid}" =~ ^[0-9]+$ ]]; then
                # Verify the PID belongs to an openclaw/clawmetry process
                local proc_cmd
                proc_cmd=$(ps -p "${pid}" -o comm= 2>/dev/null || echo "")
                if [[ "${proc_cmd}" == *"openclaw"* ]] || [[ "${proc_cmd}" == *"clawmetry"* ]] || [[ "${proc_cmd}" == *"python"* ]]; then
                    kill "${pid}" 2>/dev/null || true
                fi
            fi
            rm -f "${pid_file}"
        fi
    }

    _safe_kill_pid "${CLAWSPARK_DIR}/gateway.pid" "gateway"
    _safe_kill_pid "${CLAWSPARK_DIR}/node.pid" "node"
    _safe_kill_pid "${CLAWSPARK_DIR}/dashboard.pid" "dashboard"

    sleep 2

    # Start via systemd
    sudo systemctl start clawspark-gateway.service || {
        log_warn "Gateway systemd start failed. Check: sudo journalctl -u clawspark-gateway"
    }
    sleep 3
    sudo systemctl start clawspark-nodehost.service || {
        log_warn "Node host systemd start failed. Check: sudo journalctl -u clawspark-nodehost"
    }
    if [[ -n "${clawmetry_bin}" ]]; then
        sudo systemctl start clawspark-dashboard.service || {
            log_warn "Dashboard systemd start failed. Check: sudo journalctl -u clawspark-dashboard"
        }
    fi

    # Verify
    sleep 3
    local all_ok=true
    if sudo systemctl is-active --quiet clawspark-gateway.service; then
        log_success "Gateway running via systemd."
    else
        log_warn "Gateway not running via systemd."
        all_ok=false
    fi
    if sudo systemctl is-active --quiet clawspark-nodehost.service; then
        log_success "Node host running via systemd."
    else
        log_warn "Node host not running via systemd."
        all_ok=false
    fi
    if [[ -n "${clawmetry_bin}" ]]; then
        if sudo systemctl is-active --quiet clawspark-dashboard.service; then
            log_success "Dashboard running via systemd."
        else
            log_warn "Dashboard not running via systemd."
            all_ok=false
        fi
    fi

    if [[ "${all_ok}" == "true" ]]; then
        log_success "All services running via systemd. They will auto-start on boot."
    else
        log_warn "Some services failed to start via systemd. Use 'clawspark restart' or check journalctl."
    fi
}
