#!/bin/bash
set -euo pipefail

# This script formats all yaml files in the YAML_DIR directory using the "prettier" npm package.

# This does not work with a symlink to this script
# SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# See https://stackoverflow.com/a/246128/24637657
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

REPO_ROOT=${REPO_ROOT:-${SCRIPT_DIR}/..}

YAML_DIR=${YAML_DIR:-$REPO_ROOT/.github/workflows}

# Check if prettier is installed, if not install it globally
if ! command -v prettier &> /dev/null
then
    echo "prettier could not be found, installing it globally..."
    sudo npm install -g prettier
fi

# Format all yaml files in the directory
find "$YAML_DIR" -name "*.yaml" -o -name "*.yml" | while read -r file; do
    echo "Formatting $file"
    prettier --write "$file"
done

# Check if there are any changes after formatting
if [[ -n $(git status --porcelain) ]]; then
    echo "The following files were modified after formatting:"
    git status --porcelain
    echo "Please review the changes and commit them."
else
    echo "All yaml files are properly formatted."
fi
