#!/bin/bash

# Simple syntax check for shell scripts
echo "Running syntax check on shell scripts..."

find . -name "*.sh" -print0 | while IFS= read -r -d '' file; do
    if bash -n "$file"; then
        echo "[OK] $file"
    else
        echo "[FAIL] $file"
        exit 1
    fi
done

echo "Syntax check passed."
