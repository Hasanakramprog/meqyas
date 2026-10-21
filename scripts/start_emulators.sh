#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."

DATA_DIR="./emulator_data"

echo "=========================================================="
echo " Starting Firebase Emulator Suite with Data Persistence   "
echo " (Data will be preserved in $DATA_DIR)                    "
echo "=========================================================="

if [ -d "$DATA_DIR" ]; then
  echo "--> Loading saved data from $DATA_DIR..."
  firebase emulators:start --project demo-meqyas --import="$DATA_DIR" --export-on-exit="$DATA_DIR"
else
  echo "--> Initial run: Data will automatically be exported to $DATA_DIR on exit..."
  firebase emulators:start --project demo-meqyas --export-on-exit="$DATA_DIR"
fi

