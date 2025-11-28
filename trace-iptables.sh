#!/bin/bash

# Check if running on Linux
if [[ "$(uname)" != "Linux" ]]; then
    echo "Error: This script can only be run on Linux."
    exit 1
fi

# ==============================================================================
# Script to add or remove iptables logging rules for all chains in all tables.
# Useful for debugging IPv6 packet flow.
#
# Usage:
#   sudo ./trace-iptables.sh add
#   sudo ./trace-iptables.sh remove
#
# Logs will appear in /var/log/ufw.log, prefixed with "[UFW ".
# ==============================================================================

# --- Configuration ---
# The base prefix required to get logs into /var/log/ufw.log
LOG_PREFIX_BASE="[UFW "
# Tables to iterate through. 'raw' and 'security' are also options.
TABLES_TO_TRACE=("filter" "mangle" "nat" "raw")

# --- Functions ---

# Function to add logging rules
add_rules() {
    echo "Adding logging rules to all iptables chains..."
    for table in "${TABLES_TO_TRACE[@]}"; do
        # Get all chains for the current table
        # We use iptables-save which is reliable, then parse its output.
        chains=$(iptables-save -t "$table" | grep '^:' | cut -d ' ' -f 1 | cut -d ':' -f 2)
        if [ -z "$chains" ]; then
            echo "  -> No chains found in table '$table', skipping."
            continue
        fi

        echo "  -> Processing table: $table"
        for chain in $chains; do
            # Construct a unique and descriptive log prefix for each chain
            full_log_prefix="${LOG_PREFIX_BASE}${table:0:1}/${chain}] "
            echo "     - Adding log rule to chain: $chain"
            # Insert the logging rule at the top of the chain
            iptables -t "$table" -I "$chain" 1 -j LOG --log-prefix "$full_log_prefix"
        done
    done
    echo "Done. Logging rules have been added."
    echo "You can now monitor logs with: tail -f /var/log/ufw.log"
}

# Function to remove the logging rules
remove_rules() {
    echo "Removing logging rules from all iptables chains..."
    for table in "${TABLES_TO_TRACE[@]}"; do
        chains=$(iptables-save -t "$table" | grep '^:' | cut -d ' ' -f 1 | cut -d ':' -f 2)
        if [ -z "$chains" ]; then
            echo "  -> No chains found in table '$table', skipping."
            continue
        fi

        echo "  -> Processing table: $table"
        for chain in $chains; do
            full_log_prefix="${LOG_PREFIX_BASE}${table:0:1}/${chain}] "
            echo "     - Checking for log rule in chain: $chain"
            # Loop to remove all instances of the rule, just in case it was added multiple times.
            # The '2>/dev/null' suppresses errors when the rule doesn't exist.
            while iptables -t "$table" -D "$chain" -j LOG --log-prefix "$full_log_prefix" 2>/dev/null; do
                echo "       - Rule removed from $table/$chain."
            done
        done
    done
    echo "Done. All found logging rules have been removed."
}

# --- Main Script Logic ---

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root. Please use 'sudo'."
   exit 1
fi

# Check for iptables command
if ! command -v iptables &> /dev/null; then
    echo "Error: iptables command not found. Is it installed and in your PATH?"
    exit 1
fi

# Parse command-line arguments
case "$1" in
    add)
        add_rules
        ;;
    remove)
        remove_rules
        ;;
    *)
        echo "Usage: $0 {add|remove}"
        exit 1
        ;;
esac
