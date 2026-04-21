#!/bin/bash
set -e

# Fix RedHatAI/Qwen3.6-35B-A3B-NVFP4 config.json ignore list
# See: https://huggingface.co/RedHatAI/Qwen3.6-35B-A3B-NVFP4/discussions/4
#
# The checkpoint has combined tensor names (in_proj_qkvz, in_proj_ba) but
# config.json ignore list uses the old split names (in_proj_qkv, in_proj_z, etc.)
# This causes vLLM to skip loading linear_attn weights → garbage output.

MODEL_DIR=$(find /data -maxdepth 2 -name "config.json" -path "*Qwen3.6*NVFP4*" -exec dirname {} \; 2>/dev/null | head -1)

if [[ -z "$MODEL_DIR" ]]; then
    # Try HF cache location
    MODEL_DIR=$(find /root/.cache/huggingface -maxdepth 5 -name "config.json" -path "*Qwen3.6*NVFP4*" -exec dirname {} \; 2>/dev/null | head -1)
fi

if [[ -z "$MODEL_DIR" ]]; then
    echo "Warning: Could not find Qwen3.6-NVFP4 config.json, skipping patch"
    exit 0
fi

CONFIG="$MODEL_DIR/config.json"
echo "Patching $CONFIG to add linear_attn ignore patterns..."

python3 -c "
import json, sys

with open(sys.argv[1]) as f:
    config = json.load(f)

ignore = config.get('quantization_config', {}).get('ignore', [])
patches = [
    're:.*linear_attn\\\\.in_proj_qkvz$',
    're:.*linear_attn\\\\.in_proj_ba$'
]

changed = False
for p in patches:
    if p not in ignore:
        ignore.append(p)
        changed = True

if changed:
    config['quantization_config']['ignore'] = ignore
    with open(sys.argv[1], 'w') as f:
        json.dump(config, f, indent=2)
    print(f'  Added {len(patches)} patterns to ignore list')
else:
    print('  Patterns already present, no changes needed')
" "$CONFIG"