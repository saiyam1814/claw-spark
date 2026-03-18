#!/usr/bin/env bash
# lib/setup-browser.sh -- Browser automation setup for OpenClaw.
# Detects or installs Chromium/Chrome and configures the browser tool
# in managed headless mode.
set -euo pipefail

setup_browser() {
    log_info "Setting up browser automation..."

    local browser_bin=""
    if check_command chromium-browser; then
        browser_bin="chromium-browser"
    elif check_command chromium; then
        browser_bin="chromium"
    elif check_command google-chrome; then
        browser_bin="google-chrome"
    elif check_command google-chrome-stable; then
        browser_bin="google-chrome-stable"
    fi

    if [[ -n "${browser_bin}" ]]; then
        log_success "Browser found: ${browser_bin}"
    else
        log_info "No browser found. Installing Chromium for browser automation..."
        if check_command apt-get; then
            (sudo apt-get install -y chromium-browser 2>/dev/null || sudo apt-get install -y chromium) >> "${CLAWSPARK_LOG}" 2>&1 &
            spinner $! "Installing Chromium..."
            if check_command chromium-browser || check_command chromium; then
                browser_bin=$(command -v chromium-browser 2>/dev/null || command -v chromium)
                log_success "Chromium installed: ${browser_bin}"
            else
                log_warn "Chromium installation failed. Browser tool will not be available."
                return 0
            fi
        elif check_command brew; then
            log_info "Installing Chromium via Homebrew..."
            (brew install --cask chromium) >> "${CLAWSPARK_LOG}" 2>&1 &
            spinner $! "Installing Chromium..."
            if check_command chromium || [[ -d "/Applications/Chromium.app" ]]; then
                browser_bin=$(command -v chromium 2>/dev/null || echo "/Applications/Chromium.app/Contents/MacOS/Chromium")
                log_success "Chromium installed: ${browser_bin}"
            else
                log_warn "Chromium installation failed. Browser tool will not be available."
                return 0
            fi
        else
            log_warn "No package manager found. Install Chromium manually to enable browser automation."
            return 0
        fi
    fi

    # Configure OpenClaw browser settings in openclaw.json
    local config_file="${HOME}/.openclaw/openclaw.json"
    if [[ -f "${config_file}" ]]; then
        python3 -c "
import json, sys

path = sys.argv[1]
browser_bin = sys.argv[2]

with open(path, 'r') as f:
    cfg = json.load(f)

cfg.setdefault('browser', {})
cfg['browser']['mode'] = 'managed'
cfg['browser']['headless'] = True
cfg['browser']['executablePath'] = browser_bin

with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
print('ok')
" "${config_file}" "${browser_bin}" 2>> "${CLAWSPARK_LOG}" || {
            log_warn "Could not configure browser in openclaw.json"
        }
        log_success "Browser tool configured (managed, headless)."
    fi
}
