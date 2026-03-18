#!/usr/bin/env bash
# lib/setup-models.sh -- Multi-model configuration for OpenClaw.
# Configures vision and image generation model slots alongside the
# primary chat model that was already selected during install.
set -euo pipefail

setup_models() {
    log_info "Configuring multi-model support..."

    # The primary model is already set during install (SELECTED_MODEL_ID).
    # Now configure additional model slots: vision and image generation.

    # ── Vision model ──────────────────────────────────────────────────────
    # Check for vision-capable models already pulled in Ollama
    local vision_models=("qwen2.5-vl" "llava" "minicpm-v" "llama3.2-vision" "moondream")
    local found_vision=""

    for vm in "${vision_models[@]}"; do
        if ollama list 2>/dev/null | grep -qi "${vm}"; then
            found_vision="${vm}"
            break
        fi
    done

    if [[ -n "${found_vision}" ]]; then
        # Get the full model tag from ollama list output
        local full_tag
        full_tag=$(ollama list 2>/dev/null | grep -i "${found_vision}" | head -1 | awk '{print $1}')
        log_success "Found vision model: ${full_tag}"
        openclaw config set agents.defaults.imageModel "ollama/${full_tag}" >> "${CLAWSPARK_LOG}" 2>&1 || true
    else
        # No vision model found -- pull one automatically
        # qwen2.5-vl:7b is a good balance of quality and size (~5GB)
        local vision_choice="qwen2.5-vl:7b"
        log_info "No vision model found. Pulling ${vision_choice} for image analysis (~5GB)..."
        (ollama pull "${vision_choice}") >> "${CLAWSPARK_LOG}" 2>&1 &
        spinner $! "Pulling ${vision_choice}..."
        if ollama list 2>/dev/null | grep -qi "qwen2.5-vl"; then
            openclaw config set agents.defaults.imageModel "ollama/${vision_choice}" >> "${CLAWSPARK_LOG}" 2>&1 || true
            log_success "Vision model configured: ollama/${vision_choice}"
        else
            log_warn "Vision model pull failed. You can add one later: ollama pull qwen2.5-vl:7b"
        fi
    fi

    # ── Image generation model ────────────────────────────────────────────
    # Image generation (text-to-image) is optional and more complex.
    # It typically requires ComfyUI, Stable Diffusion, or an external API.
    # For now, log a message about how to enable it later.
    log_info "Image generation: not configured (optional)."
    log_info "  To enable later, set up ComfyUI or a text-to-image API and run:"
    log_info "  openclaw config set agents.defaults.imageGenerationModel <provider>/<model>"

    log_success "Model configuration complete."
}
