#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."

DATA_DIR="./emulator_data"

echo "=========================================================="
echo " Snapshotting Firebase Emulator Database to $DATA_DIR...  "
echo "=========================================================="

firebase emulators:export "$DATA_DIR" --project demo-meqyas

echo "✔ Data snapshot saved successfully!"
