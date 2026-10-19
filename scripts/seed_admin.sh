#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."
NODE_PATH=functions/node_modules npx -y tsx scripts/seed_admin.ts "$@"
