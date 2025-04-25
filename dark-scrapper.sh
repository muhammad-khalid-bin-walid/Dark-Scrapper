#!/usr/bin/env bash

# ANSI Color Codes for Styling
RED='\e[31;1m'
GREEN='\e[32;1m'
YELLOW='\e[33;1m'
BLUE='\e[34;1m'
CYAN='\e[36;1m'
RESET='\e[0m'

# Default Configuration
CONFIG_FILE="$HOME/.dark_scrapper.conf"
LINKFINDER_PATH="$HOME/tools/LinkFinder/linkfinder.py"
SECRETFINDER_PATH="$HOME/tools/SecretFinder/SecretFinder.py"
OUTPUT_DIR="results"
THREADS=50
CONCURRENCY=20
VERBOSITY=1
EXTENSIONS="js|json|xml"
RETRIES=3
TIMEOUT=300
LOG_FILE=""
DRY_RUN=false
JSON_LOG=false

# Progress Bar Function
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    printf "\r[${CYAN}%${filled}s${RESET}%${empty}s] %d%%" "$(printf '#%.0s' $(seq 1 $filled))" "" "$percent"
}

# Spinner Function
spinner() {
    local pid=$1
    local delay=0.1
    local spin='⠇⠋⠙⠸⠴⠦'
    echo -n "  "
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 5); do
            echo -ne "\b${spin:$i:1}"
            sleep $delay
        done
    done
    echo -ne "\b"
}

# Banner Function
banner() {
    clear
    echo ""
    echo $'\e[37;1m      █▀▄ ▄▀█ █▀█ █▄▀   █▀ █▀▀ █▀█ ▄▀█ █▀█ █▀█ █▀▀ █▀█       \e[0m'
    echo $'\e[37;1m      █▄▀ █▀█ █▀▄ █░█   ▄█ █▄▄ █▀▄ █▀█ █▀▀ █▀▀ ██▄ █▀▄       \e[0m'
    echo ""
    echo $'\e[41;5m \e[37;1m                         Dark Scrapper                         \e[0m \033[0m'
    echo $'\e[37;1m                     by Dark Legende (Ultimate)                 \e[0m'
    echo ""
}

# Help Menu
help_menu() {
    echo "${CYAN}Usage:${RESET}"
    echo "  dark_scrapper.sh [options]"
    echo ""
    echo "${CYAN}Options:${RESET}"
    echo "  -u URL           Single URL for reconnaissance"
    echo "  -l FILE          Input a list of domains"
    echo "  -o DIR           Output directory (default: $OUTPUT_DIR)"
    echo "  -t THREADS       Threads for httpx (default: $THREADS)"
    echo "  -c CONCURRENCY   Concurrency for nuclei (default: $CONCURRENCY)"
    echo "  -e EXTENSIONS    File extensions to scrape (default: $EXTENSIONS)"
    echo "  -v VERBOSITY     Verbosity level (0=quiet, 1=normal, 2=verbose; default: $VERBOSITY)"
    echo "  --dry-run        Preview commands without execution"
    echo "  --json-log       Enable JSON logging"
    echo "  -h               Display this help menu"
    echo ""
    echo "${CYAN}Features:${RESET}"
    echo "  - Subdomain enumeration: subfinder, assetfinder"
    echo "  - Live host filtering: httpx"
    echo "  - URL crawling: gau, waybackurls, subjs, getJS, katana, cariddi, gospider, hakrawler"
    echo "  - File scraping: Configurable extensions (default: .js, .json, .xml)"
    echo "  - JS analysis: LinkFinder, SecretFinder"
    echo "  - Vulnerability scanning: nuclei"
    echo "  - Screenshotting: gowitness"
    echo "  - Custom scripts: ~/.custom_scripts/"
    echo ""
    echo "${CYAN}Examples:${RESET}"
    echo "  dark_scrapper.sh -u https://example.com -t 100 -o output"
    echo "  dark_scrapper.sh -l domains.txt -e 'js|json|xml|css' -v 2"
    echo "  dark_scrapper.sh -u https://example.com --dry-run"
    echo ""
}

# Logging Function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +%Y-%m-%d\ %H:%M:%S)
    case $level in
        INFO) color=$CYAN ;;
        SUCCESS) color=$GREEN ;;
        ERROR) color=$RED ;;
        WARNING) color=$YELLOW ;;
        *) color=$RESET ;;
    esac
    if [[ $VERBOSITY -ge 1 || "$level" == "ERROR" ]]; then
        if [[ "$JSON_LOG" == "true" ]]; then
            echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\"}" >> "$LOG_FILE"
        else
            echo -e "${color}[$timestamp] [$level] $message${RESET}" | tee -a "$LOG_FILE"
        fi
    fi
    [[ "$level" == "ERROR" ]] && exit 1
}

# Check Results Function
check_results() {
    local file=$1
    if [[ -s "$file" ]]; then
        log SUCCESS "Results saved to: $file ($(wc -l < "$file") lines)"
    else
        log WARNING "No results found in: $file"
    fi
}

# Load Configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log INFO "Loaded configuration from $CONFIG_FILE"
    fi
}

# Validate Input
validate_input() {
    local option=$1
    local value=$2
    if [[ "$option" == "-u" && -z "$value" ]]; then
        log ERROR "You forgot to provide a URL."
    elif [[ "$option" == "-u" && ! "$value" =~ ^http(s)?:// ]]; then
        log ERROR "Invalid URL format: $value (must start with http:// or https://)"
    elif [[ "$option" == "-l" && ! -f "$value" ]]; then
        log ERROR "File '$value' not found."
    fi
}

# Check Tool Dependencies
check_dependencies() {
    local tools=("subfinder" "assetfinder" "httpx" "gau" "waybackurls" "subjs" "getJS" "katana" "cariddi" "gospider" "hakrawler" "nuclei" "wget" "python3" "gowitness")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log ERROR "Required tool '$tool' is not installed. Please run installer.sh."
        fi
    done
    LINKFINDER_AVAILABLE=true
    SECRETFINDER_AVAILABLE=true
    if [[ ! -f "$LINKFINDER_PATH" ]]; then
        log WARNING "LinkFinder not found at $LINKFINDER_PATH. Skipping LinkFinder analysis."
        LINKFINDER_AVAILABLE=false
    fi
    if [[ ! -f "$SECRETFINDER_PATH" ]]; then
        log WARNING "SecretFinder not found at $SECRETFINDER_PATH. Skipping SecretFinder analysis."
        SECRETFINDER_AVAILABLE=false
    fi
}

# Subdomain Enumeration
subdomain_enum() {
    local input=$1
    local output_dir=$2
    log INFO "Running subdomain enumeration..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "subfinder -d \"$input\" -o \"$output_dir/subfinder.txt\""
        echo "assetfinder --subs-only \"$input\" | tee \"$output_dir/assetfinder.txt\""
        return
    fi

    # Subfinder
    echo -ne "${CYAN}[-] Using subfinder... ${RESET}"
    (timeout $TIMEOUT subfinder -d "$input" -o "$output_dir/subfinder.txt" > "$output_dir/subfinder.log" 2>&1) &
    spinner $!
    [[ $? -ne 0 ]] && log ERROR "subfinder failed. Check $output_dir/subfinder.log"
    check_results "$output_dir/subfinder.txt"

    # Assetfinder
    echo -ne "${CYAN}[-] Using assetfinder... ${RESET}"
    (timeout $TIMEOUT assetfinder --subs-only "$input" | tee "$output_dir/assetfinder.txt" > "$output_dir/assetfinder.log" 2>&1) &
    spinner $!
    [[ $? -ne 0 ]] && log ERROR "assetfinder failed. Check $output_dir/assetfinder.log"
    check_results "$output_dir/assetfinder.txt"

    # Combine and deduplicate
    echo -ne "${CYAN}[-] Merging subdomains... ${RESET}"
    (cat "$output_dir/subfinder.txt" "$output_dir/assetfinder.txt" 2>/dev/null | sort -u > "$output_dir/subdomains.txt") &
    spinner $!
    check_results "$output_dir/subdomains.txt"
}

# Live Host Filtering
live_hosts() {
    local output_dir=$1
    log INFO "Filtering live hosts with httpx (threads=$THREADS)..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "httpx -l \"$output_dir/subdomains.txt\" -t $THREADS -silent -o \"$output_dir/live_hosts.txt\""
        return
    fi

    echo -ne "${CYAN}[-] Using httpx... ${RESET}"
    (timeout $TIMEOUT httpx -l "$output_dir/subdomains.txt" -t "$THREADS" -silent -o "$output_dir/live_hosts.txt" > "$output_dir/httpx.log" 2>&1) &
    spinner $!
    [[ $? -ne 0 ]] && log ERROR "httpx failed. Check $output_dir/httpx.log"
    check_results "$output_dir/live_hosts.txt"
}

# URL Crawling
crawl_urls() {
    local input=$1
    local output_dir=$2
    local is_file=$3
    log INFO "Crawling URLs..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "gau --subs \"$input\" | tee \"$output_dir/gau_urls.txt\""
        echo "waybackurls \"$input\" | httpx -silent -mc 200 > \"$output_dir/wayback_urls.txt\""
        return
    fi

    # Run crawlers in parallel
    local crawlers=(
        "gau --subs \"$input\" | tee \"$output_dir/gau_urls.txt\" > \"$output_dir/gau.log\" 2>&1"
        "echo \"$input\" | waybackurls | httpx -silent -mc 200 > \"$output_dir/wayback_urls.txt\" 2>&1"
        "echo \"$input\" | subjs > \"$output_dir/subjs.txt\" 2>&1"
        "echo \"$input\" | getJS --complete > \"$output_dir/getjs.txt\" 2>&1"
        "echo \"$input\" | katana -jc -silent > \"$output_dir/katanajs.txt\" 2>&1"
        "echo \"$input\" | cariddi -ext 7 > \"$output_dir/cariddijs.txt\" 2>&1"
        "gospider -s \"$input\" --js -t 5 --depth 2 --no-redirect > \"$output_dir/gospiderjs.txt\" 2>&1"
        "echo \"$input\" | hakrawler -subs -t 10 | grep \".js$\" > \"$output_dir/hakrawlerjs.txt\" 2>&1"
    )

    if [[ "$is_file" == "true" ]]; then
        crawlers=(
            "cat \"$input\" | gau --subs | tee \"$output_dir/gau_urls.txt\" > \"$output_dir/gau.log\" 2>&1"
            "cat \"$input\" | waybackurls | httpx -silent -mc 200 > \"$output_dir/wayback_urls.txt\" 2>&1"
            "cat \"$input\" | subjs > \"$output_dir/subjs.txt\" 2>&1"
            "cat \"$input\" | getJS --complete > \"$output_dir/getjs.txt\" 2>&1"
            "katana -list \"$input\" -jc -silent > \"$output_dir/katanajs.txt\" 2>&1"
            "cat \"$input\" | cariddi -ext 7 > \"$output_dir/cariddijs.txt\" 2>&1"
            "while read -r url; do gospider -s \"\$url\" --js -t 5 --depth 2 --no-redirect >> \"$output_dir/gospiderjs.txt\"; done < \"$input\" 2>&1"
            "while read -r url; do echo \"\$url\" | hakrawler -subs -t 10 | grep \".js$\" >> \"$output_dir/hakrawlerjs.txt\"; done < \"$input\" 2>&1"
        )
    fi

    local total=${#crawlers[@]}
    local current=0
    for cmd in "${crawlers[@]}"; do
        ((current++))
        tool_name=$(echo "$cmd" | awk '{print $1}')
        echo -ne "${CYAN}[-] Using $tool_name... ${RESET}"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "$cmd"
            continue
        fi
        (timeout $TIMEOUT bash -c "$cmd") &
        spinner $!
        progress_bar $current $total
        check_results "$output_dir/${tool_name}js.txt" 2>/dev/null || check_results "$output_dir/${tool_name}_urls.txt"
    done
    echo ""

    # Merge and deduplicate URLs
    echo -ne "${CYAN}[-] Merging URLs... ${RESET}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "cat \"$output_dir\"/*.txt | sort -u > \"$output_dir/all_urls.txt\""
        return
    fi
    (cat "$output_dir"/*.txt 2>/dev/null | sort -u > "$output_dir/all_urls.txt") &
    spinner $!
    check_results "$output_dir/all_urls.txt"
}

# File Scraping
scrape_files() {
    local output_dir=$1
    log INFO "Scraping files with extensions: $EXTENSIONS..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "grep -E '\.($EXTENSIONS)$' \"$output_dir/all_urls.txt\" | sort -u > \"$output_dir/files.txt\""
        return
    fi

    echo -ne "${CYAN}[-] Extracting files... ${RESET}"
    (grep -E "\.($EXTENSIONS)$" "$output_dir/all_urls.txt" | sort -u > "$output_dir/files.txt") &
    spinner $!
    check_results "$output_dir/files.txt"

    # Download files concurrently
    log INFO "Downloading files..."
    mkdir -p "$output_dir/downloads"
    local current=0
    local total=$(wc -l < "$output_dir/files.txt")
    while IFS= read -r file_url; do
        ((current++))
        filename=$(basename "$file_url" | sed 's/?.*//')
        echo -ne "${CYAN}[-] Downloading $filename... ${RESET}"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "wget -q \"$file_url\" -O \"$output_dir/downloads/$filename\""
            continue
        fi
        for ((i=1; i<=RETRIES; i++)); do
            (timeout $TIMEOUT wget -q "$file_url" -O "$output_dir/downloads/$filename" && break || log WARNING "Failed to download $file_url (attempt $i/$RETRIES)") &
            spinner $!
            [[ $? -eq 0 ]] && break
        done
        progress_bar $current $total
    done < "$output_dir/files.txt"
    echo ""
    log SUCCESS "Downloaded files to $output_dir/downloads/"
}

# JS Analysis with LinkFinder and SecretFinder
analyze_js() {
    local output_dir=$1
    log INFO "Analyzing JavaScript files..."

    if [[ "$LINKFINDER_AVAILABLE" == "false" && "$SECRETFINDER_AVAILABLE" == "false" ]]; then
        log WARNING "Skipping JavaScript analysis due to missing LinkFinder and SecretFinder."
        return
    fi

    mkdir -p "$output_dir/js_analysis"
    local current=0
    local total=$(ls "$output_dir/downloads"/*.js 2>/dev/null | wc -l)
    for js_file in "$output_dir/downloads"/*.js; do
        if [[ -f "$js_file" ]]; then
            ((current++))
            filename=$(basename "$js_file")

            # LinkFinder
            if [[ "$LINKFINDER_AVAILABLE" == "true" ]]; then
                echo -ne "${CYAN}[-] LinkFinder analyzing $filename... ${RESET}"
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "python3 \"$LINKFINDER_PATH\" -i \"$js_file\" -o \"$output_dir/js_analysis/$filename.linkfinder.html\""
                else
                    (timeout $TIMEOUT python3 "$LINKFINDER_PATH" -i "$js_file" -o "$output_dir/js_analysis/$filename.linkfinder.html" > "$output_dir/js_analysis/$filename.linkfinder.log" 2>&1) &
                    spinner $!
                    [[ $? -eq 0 ]] && log SUCCESS "LinkFinder completed for $filename" || log WARNING "LinkFinder failed for $filename. Check $output_dir/js_analysis/$filename.linkfinder.log"
                fi
            fi

            # SecretFinder
            if [[ "$SECRETFINDER_AVAILABLE" == "true" ]]; then
                echo -ne "${CYAN}[-] SecretFinder analyzing $filename... ${RESET}"
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "python3 \"$SECRETFINDER_PATH\" -i \"$js_file\" -o cli > \"$output_dir/js_analysis/$filename.secretfinder.txt\""
                else
                    (timeout $TIMEOUT python3 "$SECRETFINDER_PATH" -i "$js_file" -o cli > "$output_dir/js_analysis/$filename.secretfinder.txt" 2> "$output_dir/js_analysis/$filename.secretfinder.log") &
                    spinner $!
                    [[ $? -eq 0 ]] && log SUCCESS "SecretFinder completed for $filename" || log WARNING "SecretFinder failed for $filename. Check $output_dir/js_analysis/$filename.secretfinder.log"
                fi
            fi
            progress_bar $current $total
        fi
    done
    echo ""
    log SUCCESS "JS analysis results saved in $output_dir/js_analysis/"
}

# Screenshot Live Hosts
screenshot_hosts() {
    local output_dir=$1
    log INFO "Screenshotting live hosts with gowitness..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "gowitness file -f \"$output_dir/live_hosts.txt\" -P \"$output_dir/screenshots\" --threads $THREADS"
        return
    fi

    echo -ne "${CYAN}[-] Using gowitness... ${RESET}"
    (timeout $TIMEOUT gowitness file -f "$output_dir/live_hosts.txt" -P "$output_dir/screenshots" --threads "$THREADS" > "$output_dir/gowitness.log" 2>&1) &
    spinner $!
    [[ $? -eq 0 ]] && log SUCCESS "Screenshots saved to $output_dir/screenshots/" || log WARNING "gowitness failed. Check $output_dir/gowitness.log"
}

# Vulnerability Scanning with Nuclei
run_nuclei() {
    local output_dir=$1
    log INFO "Running nuclei (concurrency=$CONCURRENCY)..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "nuclei -l \"$output_dir/live_hosts.txt\" -c $CONCURRENCY -silent -o \"$output_dir/nuclei_results.txt\""
        return
    fi

    echo -ne "${CYAN}[-] Using nuclei... ${RESET}"
    (timeout $TIMEOUT nuclei -l "$output_dir/live_hosts.txt" -c "$CONCURRENCY" -silent -o "$output_dir/nuclei_results.txt" > "$output_dir/nuclei.log" 2>&1) &
    spinner $!
    [[ $? -ne 0 ]] && log ERROR "nuclei failed. Check $output_dir/nuclei.log"
    check_results "$output_dir/nuclei_results.txt"
}

# Custom Scripts
run_custom_scripts() {
    local target=$1
    local output_dir=$2
    local custom_scripts_dir="$HOME/custom_scripts"
    if [[ -d "$custom_scripts_dir" ]]; then
        log INFO "Running custom scripts from $custom_scripts_dir..."
        mkdir -p "$output_dir/custom_results"
        local current=0
        local total=$(ls "$custom_scripts_dir"/*.sh 2>/dev/null | wc -l)
        for script in "$custom_scripts_dir"/*.sh; do
            if [[ -f "$script" ]]; then
                ((current++))
                script_name=$(basename "$script")
                echo -ne "${CYAN}[-] Executing $script_name... ${RESET}"
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo "bash \"$script\" \"$target\" > \"$output_dir/custom_results/$script_name.out\""
                    continue
                fi
                (timeout $TIMEOUT bash "$script" "$target" > "$output_dir/custom_results/$script_name.out" 2>&1) &
                spinner $!
                [[ $? -eq 0 ]] && log SUCCESS "$script_name completed. Results in $output_dir/custom_results/$script_name.out" || log WARNING "$script_name failed. Check $output_dir/custom_results/$script_name.out"
                progress_bar $current $total
            fi
        done
        echo ""
    else
        log WARNING "Custom scripts directory ($custom_scripts_dir) not found. Skipping..."
    fi
}

# Generate Summary Report
generate_report() {
    local output_dir=$1
    log INFO "Generating summary report..."
    local report_file="$output_dir/summary.json"
    cat <<EOF > "$report_file"
{
  "timestamp": "$(date +%Y-%m-%d\ %H:%M:%S)",
  "subdomains": $(wc -l < "$output_dir/subdomains.txt"),
  "live_hosts": $(wc -l < "$output_dir/live_hosts.txt"),
  "urls": $(wc -l < "$output_dir/all_urls.txt"),
  "files": $(wc -l < "$output_dir/files.txt"),
  "nuclei_results": "$(wc -l < "$output_dir/nuclei_results.txt")",
  "js_analysis_files": $(ls "$output_dir/js_analysis"/*.html 2>/dev/null | wc -l),
  "screenshots": $(ls "$output_dir/screenshots"/*.png 2>/dev/null | wc -l),
  "custom_scripts": $(ls "$output_dir/custom_results"/*.out 2>/dev/null | wc -l),
  "output_dir": "$output_dir",
  "log_file": "$LOG_FILE"
}
EOF
    log SUCCESS "Summary report saved to $report_file"
}

# Main Workflow
main_workflow() {
    local input=$1
    local is_file=$2
    local target_name=$(echo "$input" | sed 's|http[s]*://||;s|/||g' | head -n 1)
    OUTPUT_DIR="$OUTPUT_DIR/$(date +%Y-%m-%d_%H-%M-%S)_${target_name}_$RANDOM"
    LOG_FILE="$OUTPUT_DIR/recon.log"
    mkdir -p "$OUTPUT_DIR"

    log INFO "Starting reconnaissance for $target_name"

    # Step 1: Subdomain Enumeration
    if [[ "$is_file" == "false" ]]; then
        subdomain_enum "$input" "$OUTPUT_DIR"
        live_hosts "$OUTPUT_DIR"
    else
        log INFO "Skipping subdomain enumeration for file input. Using domains directly."
        cp "$input" "$OUTPUT_DIR/subdomains.txt"
        live_hosts "$OUTPUT_DIR"
    fi

    # Step 2: URL Crawling
    crawl_urls "$input" "$OUTPUT_DIR" "$is_file"

    # Step 3: File Scraping
    scrape_files "$OUTPUT_DIR"

    # Step 4: JS Analysis
    analyze_js "$OUTPUT_DIR"

    # Step 5: Screenshot Hosts
    screenshot_hosts "$OUTPUT_DIR"

    # Step 6: Nuclei Scanning
    run_nuclei "$OUTPUT_DIR"

    # Step 7: Custom Scripts
    run_custom_scripts "$target_name" "$OUTPUT_DIR"

    # Step 8: Generate Report
    generate_report "$OUTPUT_DIR"
}

# Parse Arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u) INPUT="$2"; IS_FILE=false; shift 2 ;;
            -l) INPUT="$2"; IS_FILE=true; shift 2 ;;
            -o) OUTPUT_DIR="$2"; shift 2 ;;
            -t) THREADS="$2"; shift 2 ;;
            -c) CONCURRENCY="$2"; shift 2 ;;
            -e) EXTENSIONS="$2"; shift 2 ;;
            -v) VERBOSITY="$2"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --json-log) JSON_LOG=true; shift ;;
            -h) help_menu; exit 0 ;;
            *) log ERROR "Invalid option: $1. Use -h for help."; exit 1 ;;
        esac
    done
    validate_input "${IS_FILE:+ -l}" "$INPUT"
}

# Main Execution
main() {
    banner
    load_config
    parse_args "$@"
    check_dependencies
    main_workflow "$INPUT" "$IS_FILE"
}

# Execute the script
main "$@"
