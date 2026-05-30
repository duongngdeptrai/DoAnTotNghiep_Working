#!/usr/bin/env bash
set -o errexit

echo "=== Installing dependencies ==="
pip install --upgrade pip
pip install --only-binary=:all: -r backend/requirements.txt

echo "=== Build complete ==="
