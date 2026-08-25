#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
"$script_dir/build-app.sh" debug
pkill -x Namespaces 2>/dev/null || true
open "$project_dir/build/Namespaces.app"
