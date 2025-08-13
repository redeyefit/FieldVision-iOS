#!/bin/bash

# ------------------------------
# FieldVision Full Repo Prep
# Organizes code, updates files, and readies for launch
# ------------------------------

set -e

# Step 0: Confirm folder structure
mkdir -p logs
mkdir -p modules
mkdir -p tests
mkdir -p configs

# Step 1: Sync .env
if [ ! -f .env ]; then
  cp .env.example .env
  echo "✅ .env file created. Please edit it with your API keys."
else
  echo "✅ .env file exists."
fi

# Step 2: Run Code Formatter
echo "🎨 Formatting all Python files..."
black *.py modules/*.py || echo "⚠️ black not installed"

# Step 3: Lint check (optional)
echo "🔍 Running lint (optional)..."
pylint *.py modules/*.py || echo "⚠️ pylint warnings present"

# Step 4: Final Operator Polish
echo "🧽 Polish Pass: UX & Logging Layer enabled"
echo "---"
echo "📂 Project Structure"
tree -L 2 || echo "(Install tree if you want visual directory)"

# Step 5: Prompt to run daemon
read -p "Run FieldVision Daemon now? (y/n): " yn
case $yn in
    [Yy]* ) python fieldvision_daemon.py;;
    * ) echo "💤 Daemon launch skipped. Ready for manual run.";;
esac
