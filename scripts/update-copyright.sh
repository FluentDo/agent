#!/bin/bash
set -euxo pipefail

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
SOURCE_ROOT=${SOURCE_ROOT:-$REPO_ROOT/source}

# Update the copyright year in all files in the SOURCE_ROOT directory

# Iterate over all files in the SOURCE_ROOT directory but only in the "include" and "src" subdirectories
# For each file, check that the copyright statement includes the current year, and if not, update it to include the current year.
# The format will be "Copyright (C) 20XX-20XX The Fluent Bit Authors"
# where the first year is the year of the first commit and the second year is the current year.
# If the copyright statement does not include a year range, add the current year to the end of the statement.
# If the copyright statement does not include the current year, update it to include the current year.
# If the copyright statement does not include the year at all, add the current year to the end of the statement.
CURRENT_YEAR=$(date +"%Y")
find "$SOURCE_ROOT" -type f \( -path "*/include/*" -o -path "*/src/*" \) -exec sed -i -E "s/(Copyright \(C\) [0-9]{4})-([0-9]{4})? The Fluent Bit Authors/\1-$CURRENT_YEAR The Fluent Bit Authors/g" {} \;
