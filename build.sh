#!/usr/bin/env bash
# Run this script from the zmk-config directory
# Usage: ./build.sh [left] [ARGS...]

set -e
set -o pipefail

SHIELD_SIDE="${SHIELD_SIDE:-left}"

# Color codes for output
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=''
  NC=''
fi

build_dev_container() {

  mkdir -p base
  container create -it \
    --security-opt label=disable \
    --workdir /workspaces/zmk-config \
    -v "$PWD":/workspaces/zmk-config \
    -v "$PWD"/config:/workspaces/zmk-config/base/config \
    -p 3000:3000 \
    --name zmk-build \
    zmk-build \
    /bin/bash

  container start zmk-build
  container exec -itw /workspaces/zmk-config/base zmk-build bash -c 'test -d .west || west init -l config; west update --fetch-opt=--filter=tree:0; west zephyr-export'
}

build_side() {
  if [[ -n $SHIELD_SIDE ]]; then
    if [[ $SHIELD_SIDE = "left" ]]; then
      left=1
      container exec \
        -itw /workspaces/zmk-config/base \
        zmk-build bash -c \
        "west zephyr-export; west build -s zmk/app -d build/$SHIELD_SIDE -b 'nice_nano_v2' -S 'studio-rpc-usb-uart' -- -DZMK_CONFIG=/workspaces/zmk-config/base/config -DSHIELD='sofle_left nice_view_adapter nice_view_gem' -DZMK_EXTRA_MODULES='/workspaces/zmk-config' -DCONFIG_ZMK_STUDIO=y"
      cp base/build/$SHIELD_SIDE/zephyr/zmk.uf2 zmk-$SHIELD_SIDE.uf2
    fi

    if [[ $SHIELD_SIDE = "right" ]]; then
      right=1
      container exec \
        -itw /workspaces/zmk-config/base \
        zmk-build bash -c \
        "west zephyr-export; west build -s zmk/app -d build/$SHIELD_SIDE -b 'nice_nano_v2' -S 'studio-rpc-usb-uart' -- -DZMK_CONFIG=/workspaces/zmk-config/base/config -DSHIELD='sofle_right nice_view_adapter nice_view_gem' -DZMK_EXTRA_MODULES='/workspaces/zmk-config' -DCONFIG_ZMK_STUDIO=y"
      cp base/build/$SHIELD_SIDE/zephyr/zmk.uf2 zmk-$SHIELD_SIDE.uf2
    fi
  fi
}

show_usage() {
  cat <<EOF
${BOLD}ZMK Config Build${NC}

Builds your ZMK-config locally

${BOLD}USAGE:${NC}
    build.sh --side [left|right] 

${BOLD}OPTIONS:${NC}
    ${BOLD}Version Options:${NC}
    --side                      Which side to build
                                Example: --version v0.0.11
    --build-dev-container       Build the ZMK dev container used to build firmware
    --help, -h                  Show this help message
EOF
}
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --side)
      SHIELD_SIDE="$2"
      shift 2
      ;;
    --build-dev-container)
      build_dev_container
      shift 2
      ;;
    --help | -h)
      show_usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      show_usage
      exit 1
      ;;
    esac
  done
}

main() {
  parse_args "$@"
  build_side
}

main "$@"
