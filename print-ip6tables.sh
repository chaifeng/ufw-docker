#!/bin/bash
# Recursively shows ip6tables rules with call order, indentation, and color highlighting.

# Check if running on Linux
if [[ "$(uname)" != "Linux" ]]; then
    echo "Error: This script can only be run on Linux."
    exit 1
fi

# --- Configuration ---
# String used for indentation
INDENT="    "

# --- Color Definitions ---
RESET='\033[0m'
BOLD='\033[1m'
# Foreground colors
FG_RED='\033[0;31m'
FG_GREEN='\033[0;32m'
FG_YELLOW='\033[0;33m'
FG_BLUE='\033[0;34m'
FG_MAGENTA='\033[0;35m'
FG_CYAN='\033[0;36m'
# Bold foreground colors
B_RED='\033[1;31m'
B_GREEN='\033[1;32m'
B_YELLOW='\033[1;33m'
B_BLUE='\033[1;34m'
B_MAGENTA='\033[1;35m'
B_CYAN='\033[1;36m'
B_WHITE='\033[1;37m'
# Background colors
BG_RED_WHITE="${BOLD}\033[41;37m"


# --- Global Variables ---
declare -A all_rules
declare -A table_base_chains

# --- Function Definitions ---

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${B_RED}Error: This script must be run as root to read ip6tables rules.${RESET}" 1>&2
        exit 1
    fi
}

# Check if ip6tables-save command exists
check_command() {
    if ! command -v ip6tables-save &> /dev/null; then
        echo -e "${B_RED}Error: 'ip6tables-save' command not found.${RESET}" 1>&2
        echo -e "${B_RED}Please ensure 'ip6tables' package is installed.${RESET}" 1>&2
        exit 1
    fi
}

# Parse ip6tables-save output and load into associative array
load_rules() {
    local current_table=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^\*(.*) ]]; then
            current_table="${BASH_REMATCH[1]}"
            table_base_chains["$current_table"]=""
        elif [[ -n "$current_table" ]]; then
            if [[ "$line" =~ ^:([A-Za-z0-9_-]+)[[:space:]](ACCEPT|DROP|RETURN) ]]; then
                local chain_name="${BASH_REMATCH[1]}"
                table_base_chains["$current_table"]+="$chain_name "
            fi
            if [[ "$line" =~ ^-A[[:space:]]+([A-Za-z0-9_-]+) ]]; then
                local chain_name="${BASH_REMATCH[1]}"
                all_rules["$current_table,$chain_name"]+="$line"$'\n'
            fi
        fi
    done < <(ip6tables-save 2>/dev/null)
}

# Highlight and print a single rule
# Arguments:
#   $1: Prefix
#   $2: Rule content
highlight_and_print_rule() {
    local prefix="$1"
    local rule="$2"
    local colored_rule="$rule"

    # --- Step 1: Highlight log prefix string ---
    # Match --log-prefix and its argument (quoted or unquoted)
    if [[ "$colored_rule" =~ (--log-prefix[[:space:]]+)(".*?"|'.*?'|[^[:space:]]+) ]]; then
        local full_match="${BASH_REMATCH[0]}"
        local flag_part="${BASH_REMATCH[1]}"
        local value_part="${BASH_REMATCH[2]}"
        # Highlight the log content itself
        local colored_value="${B_YELLOW}${value_part}${RESET}"
        local replacement="${flag_part}${colored_value}"
        # Use Bash global replacement just in case
        colored_rule="${colored_rule//$full_match/$replacement}"
    fi

    # --- Step 2: Highlight jump targets ---
    # Continue on potentially partially colored string
    if [[ "$colored_rule" =~ ((-j|--jump)[[:space:]]+)([a-zA-Z0-9_-]+) ]]; then
        local full_match="${BASH_REMATCH[0]}"      # e.g., "-j ACCEPT"
        local flag_part="${BASH_REMATCH[1]}"       # e.g., "-j "
        local jump_target="${BASH_REMATCH[3]}"     # e.g., "ACCEPT"
        local colored_target=""

        case "$jump_target" in
            ACCEPT)              colored_target="${B_GREEN}${jump_target}${RESET}" ;;
            DROP|REJECT)         colored_target="${B_RED}${jump_target}${RESET}" ;;
            LOG)                 colored_target="${B_YELLOW}${jump_target}${RESET}" ;;
            RETURN)              colored_target="${B_BLUE}${jump_target}${RESET}" ;;
            MASQUERADE|SNAT|DNAT|REDIRECT|TPROXY) colored_target="${B_CYAN}${jump_target}${RESET}" ;;
            *)                   colored_target="${B_BLUE}${jump_target}${RESET}" ;; # User defined chain
        esac
        
        # Exact replacement of "-j TARGET" part to avoid false positives
        local replacement="${flag_part}${colored_target}"
        colored_rule="${colored_rule//$full_match/$replacement}"
    fi

    # Use -e option to parse color codes
    echo -e "${prefix}${colored_rule}"
}


# Recursively print rule chains
print_chain_recursively() {
    local table_name="$1"
    local chain_name="$2"
    local prefix="$3"
    local call_stack="$4"

    # --- Loop detection ---
    if [[ ",${call_stack}," == *,${chain_name},* ]]; then
        echo -e "${prefix}${BG_RED_WHITE}#--> [Loop Detected]${RESET} ${B_RED}Attempting to jump to '${chain_name}', but it is already in the call stack.${RESET}"
        return
    fi
    local new_call_stack="${call_stack:+$call_stack,}$chain_name"

    # --- Get rules for current chain ---
    local rules=${all_rules["$table_name,$chain_name"]}
    if [[ -z "$rules" ]]; then
        return
    fi
    
    # --- Process and print rules one by one ---
    while IFS= read -r rule; do
        if [[ -n "$rule" ]]; then
            # Call highlight function to print rule
            highlight_and_print_rule "$prefix" "$rule"
            
            # Check if rule has a jump target
            if [[ "$rule" =~ (-j|--jump)[[:space:]]+([a-zA-Z0-9_-]+) ]]; then
                local target_chain="${BASH_REMATCH[2]}"
                
                # Exclude standard targets that are not chains
                case "$target_chain" in
                    ACCEPT|DROP|REJECT|LOG|RETURN|MASQUERADE|DNAT|SNAT|REDIRECT|CT|TPROXY|CLASSIFY|NFLOG|NFQUEUE)
                        # These are terminal targets, do not recurse
                        ;;
                    *)
                        # This is a jump to another chain, recurse
                        print_chain_recursively "$table_name" "$target_chain" "${prefix}${INDENT}" "$new_call_stack"
                        ;;
                esac
            fi
        fi
    done <<< "$rules"
}


# --- Main Program ---
main() {
    check_root
    check_command
    
    echo -e "${B_WHITE}Loading and parsing ip6tables rules...${RESET}"
    load_rules
    echo

    if [ ${#table_base_chains[@]} -eq 0 ]; then
        echo -e "${B_YELLOW}No ip6tables rules or tables found.${RESET}"
        exit 0
    fi

    for table in "${!table_base_chains[@]}"; do
        echo -e "${B_MAGENTA}--- Table: ${table} ---${RESET}"
        
        local base_chains=${table_base_chains["$table"]}
        if [[ -z "$base_chains" ]]; then
            echo -e "${FG_YELLOW}No entry chains with default policies found in this table.${RESET}"
            echo
            continue
        fi

        for chain in $base_chains; do
            echo
            echo -e "-> ${B_YELLOW}Entry Point: Chain '${chain}'${RESET}"
            print_chain_recursively "$table" "$chain" "  " ""
        done
        echo -e "${B_MAGENTA}--- End of Table: ${table} ---${RESET}"
        echo
    done
}

# --- Execute Main ---
main