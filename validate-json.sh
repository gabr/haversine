#/bin/bash
set -eu # exit on error and if there is unassigned variable use
# provide file path as first argument to the script
json_pp < "$1" 1>/dev/null
