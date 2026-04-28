{ pkgs, ... }:
let
  # Vulkan gives laptop/desktop iGPUs a useful local lane. Examples are enabled
  # for llama-lookup, which provides n-gram speculative decoding without a draft
  # model and is useful for repeated prompts (voice intents, small transforms).
  llama = (pkgs.llama-cpp.override { vulkanSupport = true; }).overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DLLAMA_BUILD_EXAMPLES=ON" ];
  });
in
pkgs.writeShellApplication {
  name = "ask-local";
  runtimeInputs = [
    llama
    pkgs.coreutils
    pkgs.curl
  ];
  text = ''
    # One-shot or server-mode local LLM on the user's machine.
    #
    #   ask-local "<prompt>"                  -> llama-cli completion to stdout
    #   ask-local --fast "<prompt>"           -> llama-lookup n-gram speculative path
    #   ask-local --grammar file.gbnf "..."   -> constrained decoding
    #   ask-local --serve                      -> OpenAI-compatible server
    #
    # Env knobs:
    #   ASK_LOCAL_MODEL  .gguf path
    #   ASK_LOCAL_HOST   server bind address (default 127.0.0.1)
    #   ASK_LOCAL_PORT   server port (default 8088)
    #   ASK_LOCAL_CTX    context size (default 4096)
    #   ASK_LOCAL_NGL    GPU layers (default 99)
    #   ASK_LOCAL_N      max generated tokens for one-shot mode (default 256)
    # shellcheck source=/dev/null
    . ${./fetch-model.sh}

    MODEL="''${ASK_LOCAL_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/llama/Phi-3-mini-4k-instruct-Q4_K_M.gguf}"
    fetch_model "$MODEL" \
      https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf

    CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/ask-local"
    mkdir -p "$CACHE"

    HOST="''${ASK_LOCAL_HOST:-127.0.0.1}"
    PORT="''${ASK_LOCAL_PORT:-8088}"
    CTX="''${ASK_LOCAL_CTX:-4096}"
    NGL="''${ASK_LOCAL_NGL:-99}"
    N="''${ASK_LOCAL_N:-256}"

    if [[ "''${1:-}" == "--serve" ]]; then
      exec llama-server -m "$MODEL" -ngl "$NGL" --ctx-size "$CTX" \
        --host "$HOST" --port "$PORT" \
        -lcd "$CACHE/lookup.ngram" --spec-type ngram-cache --draft-max 16
    fi

    fast=''${ASK_LOCAL_LOOKUP:-0}
    extra=()
    while true; do
      case "''${1:-}" in
        --fast) fast=1; shift ;;
        --grammar)
          [[ $# -ge 2 ]] || { echo "ask-local: --grammar needs a file" >&2; exit 2; }
          extra+=(--grammar-file "$2" -n 128); shift 2 ;;
        *) break ;;
      esac
    done

    if [[ $fast -eq 1 ]]; then
      exec llama-lookup -m "$MODEL" -ngl "$NGL" --ctx-size "$CTX" "''${extra[@]}" \
        -lcd "$CACHE/lookup.ngram" --draft-max 16 --color off -p "$*" 2>/dev/null
    fi

    exec llama-cli -m "$MODEL" -ngl "$NGL" --ctx-size "$CTX" "''${extra[@]}" \
      -no-cnv -n "$N" --no-display-prompt -p "$*" 2>/dev/null
  '';
}
