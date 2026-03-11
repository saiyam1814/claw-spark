#!/usr/bin/env bash
# lib/select-model.sh — Recommends and lets the user pick an LLM based on hardware.
# Exports: SELECTED_MODEL_ID, SELECTED_MODEL_NAME, SELECTED_MODEL_CTX
set -euo pipefail

select_model() {
    log_info "Selecting model for ${HW_PLATFORM}..."

    # ── Build model roster for the detected platform ────────────────────────
    local -a model_ids=()
    local -a model_names=()
    local -a model_labels=()
    local default_idx=0

    case "${HW_PLATFORM}" in
        dgx-spark)
            model_ids=("qwen3.5:35b-a3b" "qwen3.5:122b" "glm-4.7-flash")
            model_names=("Qwen 3.5 35B-A3B" "Qwen 3.5 122B" "GLM 4.7 Flash")
            model_labels=(
                "Balanced (default) — MoE, ~59 tok/s"
                "Maximum quality — 122B model (81GB)"
                "Lightweight — compact & fast"
            )
            default_idx=0
            ;;
        jetson)
            model_ids=("nemotron-3-nano" "glm-4.7-flash")
            model_names=("Nemotron 3 Nano 30B" "GLM 4.7 Flash")
            model_labels=(
                "Balanced (default) — optimized for Jetson"
                "Lightweight — compact & fast"
            )
            default_idx=0
            ;;
        rtx)
            if (( HW_GPU_VRAM_MB >= 24576 )); then
                # >= 24 GB VRAM
                model_ids=("qwen3.5:35b-a3b" "glm-4.7-flash")
                model_names=("Qwen 3.5 35B-A3B" "GLM 4.7 Flash")
                model_labels=(
                    "Balanced (default) — MoE Q4, fits 24 GB"
                    "Lightweight — compact & fast"
                )
            else
                # < 24 GB VRAM
                model_ids=("glm-4.7-flash" "qwen3:8b")
                model_names=("GLM 4.7 Flash" "Qwen3 8B")
                model_labels=(
                    "Balanced (default) — fits smaller VRAM"
                    "Lightweight — compact 8B model"
                )
            fi
            default_idx=0
            ;;
        *)
            model_ids=("glm-4.7-flash" "qwen3:8b")
            model_names=("GLM 4.7 Flash" "Qwen3 8B")
            model_labels=(
                "Balanced (default)"
                "Lightweight"
            )
            default_idx=0
            ;;
    esac

    # Add a "Let me pick" sentinel
    model_labels+=("Let me pick my own model")

    # ── If --model was passed on command line, use it directly ──────────────
    if [[ -n "${FLAG_MODEL:-}" ]]; then
        SELECTED_MODEL_ID="${FLAG_MODEL}"
        SELECTED_MODEL_NAME="${FLAG_MODEL}"
        SELECTED_MODEL_CTX=32768
        export SELECTED_MODEL_ID SELECTED_MODEL_NAME SELECTED_MODEL_CTX
        log_success "Model set via command line: ${SELECTED_MODEL_ID}"
        return 0
    fi

    # ── Interactive selection ───────────────────────────────────────────────
    local choice
    choice=$(prompt_choice "Which model would you like to run?" model_labels "${default_idx}")

    # Check if user chose "Let me pick"
    if [[ "${choice}" == "Let me pick my own model" ]]; then
        if [[ "${CLAWSPARK_DEFAULTS}" == "true" ]]; then
            # In defaults mode fall back to the default model
            SELECTED_MODEL_ID="${model_ids[$default_idx]}"
            SELECTED_MODEL_NAME="${model_names[$default_idx]}"
        else
            printf '\n  %sEnter the Ollama model ID (e.g. llama3:8b):%s ' "${BOLD}" "${RESET}"
            local custom_id
            read -r custom_id </dev/tty || custom_id=""
            if [[ -z "${custom_id}" ]]; then
                log_warn "No model entered — falling back to default."
                SELECTED_MODEL_ID="${model_ids[$default_idx]}"
                SELECTED_MODEL_NAME="${model_names[$default_idx]}"
            else
                SELECTED_MODEL_ID="${custom_id}"
                SELECTED_MODEL_NAME="${custom_id}"
            fi
        fi
    else
        # Map the chosen label back to its index
        local i
        local found=false
        for i in $(seq 0 $(( ${#model_labels[@]} - 2 ))); do
            if [[ "${model_labels[$i]}" == "${choice}" ]]; then
                SELECTED_MODEL_ID="${model_ids[$i]}"
                SELECTED_MODEL_NAME="${model_names[$i]}"
                found=true
                break
            fi
        done
        if [[ "${found}" != "true" ]]; then
            log_warn "Could not match selection -- using default model."
            SELECTED_MODEL_ID="${model_ids[$default_idx]}"
            SELECTED_MODEL_NAME="${model_names[$default_idx]}"
        fi
    fi

    SELECTED_MODEL_CTX=32768
    export SELECTED_MODEL_ID SELECTED_MODEL_NAME SELECTED_MODEL_CTX

    printf '\n'
    print_box \
        "${BOLD}Model Selected${RESET}" \
        "" \
        "Name    : ${CYAN}${SELECTED_MODEL_NAME}${RESET}" \
        "ID      : ${SELECTED_MODEL_ID}" \
        "Context : ${SELECTED_MODEL_CTX} tokens"

    log_success "Model selected: ${SELECTED_MODEL_NAME} (${SELECTED_MODEL_ID})"
}
