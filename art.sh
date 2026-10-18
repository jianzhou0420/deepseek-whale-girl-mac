#!/bin/zsh
# Art asset pipeline (see art-pipeline/Pipeline.swift). Needs Codex CLI signed in with a ChatGPT plan.
set -e
cd "$(dirname "$0")/art-pipeline"
mkdir -p .build
if [[ ! -x .build/pipeline || Pipeline.swift -nt .build/pipeline ]]; then
  swiftc -O Pipeline.swift -o .build/pipeline
fi
exec .build/pipeline "$@"
