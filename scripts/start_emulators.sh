#!/usr/bin/env bash
set -e

echo "Starting Firebase Emulator Suite for Maqyas (Auth, Functions, Firestore, Storage)..."
firebase emulators:start --project demo-meqyas
