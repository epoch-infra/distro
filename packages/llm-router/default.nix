{ pkgs, ... }:
# Request-shape proxy: local small/no-tool prompts -> desktop-local model;
# larger/tool prompts -> offload server. OpenAI-compatible in and out.
pkgs.writers.writePython3Bin "llm-router" {
  flakeIgnore = [ "E501" ];
} ./llm-router.py
