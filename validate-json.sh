#/bin/bash
# A helper script to validate if generated JSON files are correct.
set -eu # exit on error and if there is unassigned variable use
# provide file path as first argument to the script
json_pp < "$1" 1>/dev/null
