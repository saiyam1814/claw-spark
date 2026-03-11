#!/usr/bin/env bash
# lib/setup-inference.sh — Installs Ollama, pulls the chosen model, and
# waits for the inference API to become ready.
# Exports: INFERENCE_API_URL
set -euo pipefail

setup_inference() {
    log_info "Setting up inference engine (Ollama)..."
    hr

    # ── Install Ollama if missing ───────────────────────────────────────────
    if ! check_command ollama; then
        log_info "Ollama not found — installing..."
        (curl -fsSL https://ollama.com/install.sh | sh) >> "${CLAWSPARK_LOG}" 2>&1 &
        spinner $! "Installing Ollama..."
        if ! check_command ollama; then
            log_error "Ollama installation failed. Check ${CLAWSPARK_LOG} for details."
            return 1
        fi
        log_success "Ollama installed."
    else
        log_success "Ollama is already installed."
    fi

    # ── Start Ollama service ────────────────────────────────────────────────
    if ! _ollama_is_running; then
        log_info "Starting Ollama service..."
        if check_command systemctl && systemctl is-enabled ollama &>/dev/null; then
            sudo systemctl start ollama >> "${CLAWSPARK_LOG}" 2>&1 || true
        else
            # Start as a background process
            nohup ollama serve >> "${CLAWSPARK_DIR}/ollama.log" 2>&1 &
            local serve_pid=$!
            echo "${serve_pid}" > "${CLAWSPARK_DIR}/ollama.pid"
            log_info "Ollama serve started (PID ${serve_pid})."
        fi

        # Wait for the service to be ready
        _wait_for_ollama 30
    else
        log_success "Ollama is already running."
    fi

    # ── Pull the selected model ─────────────────────────────────────────────
    log_info "Pulling model: ${SELECTED_MODEL_ID} (this may take a while)..."
    if ollama list 2>/dev/null | grep -q "${SELECTED_MODEL_ID}"; then
        log_success "Model ${SELECTED_MODEL_ID} is already available locally."
    else
        ollama pull "${SELECTED_MODEL_ID}" 2>&1 | tee -a "${CLAWSPARK_LOG}"
        local pull_rc=${PIPESTATUS[0]}
        if [[ ${pull_rc} -ne 0 ]]; then
            log_error "Failed to pull model ${SELECTED_MODEL_ID}."
            return 1
        fi
        log_success "Model ${SELECTED_MODEL_ID} downloaded."
    fi

    # ── Verify model is listed ──────────────────────────────────────────────
    if ! ollama list 2>/dev/null | grep -q "${SELECTED_MODEL_ID}"; then
        log_error "Model ${SELECTED_MODEL_ID} not found in ollama list after pull."
        return 1
    fi

    # ── Set API URL ─────────────────────────────────────────────────────────
    INFERENCE_API_URL="http://127.0.0.1:11434/v1"
    export INFERENCE_API_URL

    log_success "Inference engine ready at ${INFERENCE_API_URL}"
}

# ── Internal helpers ────────────────────────────────────────────────────────

_ollama_is_running() {
    curl -sf http://127.0.0.1:11434/ &>/dev/null
}

_wait_for_ollama() {
    local max_attempts="${1:-30}"
    local attempt=0
    while (( attempt < max_attempts )); do
        if _ollama_is_running; then
            log_success "Ollama API is responsive."
            return 0
        fi
        attempt=$(( attempt + 1 ))
        sleep 1
    done
    log_error "Ollama did not become ready after ${max_attempts}s."
    return 1
}
