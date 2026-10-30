
#!/usr/bin/env bash

# ============================================================
# CYBERGUARD
# Automated Cybersecurity Assessment Tool
# ============================================================

set -u

clear 2>/dev/null || true

echo "=================================================="
echo "                    CYBERGUARD"
echo "       Automated Cybersecurity Assessment Tool"
echo "=================================================="
echo

read -r -p "Enter authorized domain, IP, or URL: " target

if [[ -z "${target//[[:space:]]/}" ]]; then
    echo "[-] No target entered. Exiting."
    exit 1
fi

read -r -p "Confirm authorization (type yes): " consent
if [[ "$consent" != "yes" ]]; then
    echo "[-] Authorization not confirmed. Exiting."
    exit 1
fi

# Determine target host and URL
if [[ "$target" =~ ^https?:// ]]; then
    web_target="$target"
    remainder="${target#http://}"
    remainder="${remainder#https://}"
    host="${remainder%%/*}"
else
    host="${target%%/*}"
    web_target="http://$target"
fi

host="${host%%:*}"

if [[ -z "$host" ]]; then
    echo "[-] Invalid target."
    exit 1
fi

mkdir -p recon_results network_results web_results \
    web_results/sqlmap_output report

# Remove old AI report so a failed run cannot be mistaken for success.
rm -f report/cyberguard_AI_Assessment.html

status() {
    echo "$1"
    echo "$1" >> report/scan_status.txt
}

run_tool() {
    local name="$1"
    local output="$2"
    shift 2

    status "[+] $name started..."
    if "$@" > "$output" 2>&1; then
        status "[✓] $name completed. Results saved."
        printf 'COMPLETED\n' > "${output}.status"
    else
        local rc=$?
        status "[!] $name failed (exit $rc). See $output"
        printf 'FAILED (exit %s)\n' "$rc" > "${output}.status"
    fi
}

skip_tool() {
    local name="$1"
    local output="$2"
    local reason="$3"
    printf '%s\n' "$reason" > "$output"
    printf 'SKIPPED: %s\n' "$reason" > "${output}.status"
    status "[-] $name skipped: $reason"
}

: > report/scan_status.txt

{
    echo "CYBERGUARD AUTOMATED SECURITY ASSESSMENT"
    echo "Target: $target"
    echo "Host: $host"
    echo "Web URL: $web_target"
    echo "Started: $(date)"
} > report/scan_metadata.txt

# ============================================================
# 1. RECONNAISSANCE
# ============================================================

status ""
status "[+] Reconnaissance started..."

if command -v whois >/dev/null 2>&1; then
    run_tool "WHOIS" recon_results/whois.txt whois "$host"
else
    skip_tool "WHOIS" recon_results/whois.txt "whois not installed"
fi

if command -v dig >/dev/null 2>&1; then
    status "[+] DNS lookup started..."
    {
        for record in A AAAA NS MX TXT CNAME; do
            echo
            echo "========== $record RECORD =========="
            dig +time=3 +tries=1 "$host" "$record" +noall +answer
        done
    } > recon_results/dig.txt 2>&1
    status "[✓] DNS lookup completed."
else
    skip_tool "DIG" recon_results/dig.txt "dig not installed"
fi

if command -v subfinder >/dev/null 2>&1; then
    run_tool "Subfinder" recon_results/subfinder.txt \
        subfinder -d "$host" -silent
else
    skip_tool "Subfinder" recon_results/subfinder.txt "subfinder not installed"
fi

if command -v sublist3r >/dev/null 2>&1; then
    status "[+] Sublist3r started..."
    if sublist3r -d "$host" -o recon_results/sublist3r.txt \
        > recon_results/sublist3r.log 2>&1; then
        status "[✓] Sublist3r completed."
    else
        rc=$?
        echo "Sublist3r failed (exit $rc)." > recon_results/sublist3r.txt
        status "[!] Sublist3r failed. See recon_results/sublist3r.log"
    fi
else
    skip_tool "Sublist3r" recon_results/sublist3r.txt "sublist3r not installed"
fi

if command -v theHarvester >/dev/null 2>&1; then
    run_tool "theHarvester" recon_results/theHarvester.txt \
        theHarvester -d "$host" -b duckduckgo
else
    skip_tool "theHarvester" recon_results/theHarvester.txt \
        "theHarvester not installed"
fi

if command -v whatweb >/dev/null 2>&1; then
    run_tool "WhatWeb" recon_results/whatweb.txt whatweb "$web_target"
else
    skip_tool "WhatWeb" recon_results/whatweb.txt "whatweb not installed"
fi

status "[✓] Reconnaissance completed."

# ============================================================
# 2. NETWORK SCANNING
# ============================================================

status ""
status "[+] Network scanning started..."

if command -v nmap >/dev/null 2>&1; then
    run_tool "Nmap" network_results/nmap_scan.txt \
        nmap -sV --version-light -oN network_results/nmap_output.txt "$host"
else
    skip_tool "Nmap" network_results/nmap_scan.txt "nmap not installed"
fi

status "[✓] Network scanning completed."

# ============================================================
# 3. WEB SECURITY ASSESSMENT
# ============================================================

status ""
status "[+] Web security assessment started..."

if command -v nikto >/dev/null 2>&1; then
    run_tool "Nikto" web_results/nikto.txt \
        nikto -h "$web_target" -nointeractive -maxtime 5m
else
    skip_tool "Nikto" web_results/nikto.txt "nikto not installed"
fi

# Directory discovery
default_wordlist="/usr/share/dirb/wordlists/common.txt"
read -r -p "Wordlist path (Enter for default): " wordlist
[[ -z "$wordlist" ]] && wordlist="$default_wordlist"

if command -v dirb >/dev/null 2>&1 && [[ -f "$wordlist" ]]; then
    run_tool "DIRB" web_results/dirb.log \
        dirb "$web_target" "$wordlist" -o web_results/dirb_output.txt

    if [[ -f web_results/dirb_output.txt ]]; then
        cp web_results/dirb_output.txt web_results/dirbuster.txt
    else
        echo "DIRB output was not created." > web_results/dirbuster.txt
    fi
else
    if [[ ! -f "$wordlist" ]]; then
        skip_tool "DIRB" web_results/dirbuster.txt "Wordlist not found: $wordlist"
    else
        skip_tool "DIRB" web_results/dirbuster.txt "dirb not installed"
    fi
fi

# Joomla detection
if command -v joomscan >/dev/null 2>&1 &&
   grep -qi Joomla recon_results/whatweb.txt 2>/dev/null; then
    run_tool "JoomScan" web_results/joomscan.txt \
        joomscan -u "$web_target"
else
    skip_tool "JoomScan" web_results/joomscan.txt \
        "Joomla not detected or JoomScan not installed"
fi

# ============================================================
# SQLMAP - USER-PROVIDED URL/PARAMETERS
# ============================================================

if command -v sqlmap >/dev/null 2>&1; then
    echo
    echo "========== SQLMAP =========="
    echo "Use an authorized lab URL with a real parameter."
    echo "Example: http://127.0.0.1/DVWA/vulnerabilities/sqli/?id=1"
    echo

    read -r -p "SQLmap test URL (Enter to skip): " sqlmap_url

    if [[ -z "$sqlmap_url" ]]; then
        skip_tool "SQLmap" web_results/sqlmap.txt "User skipped SQLmap URL"
    elif [[ ! "$sqlmap_url" =~ ^https?:// ]]; then
        skip_tool "SQLmap" web_results/sqlmap.txt "A full HTTP/HTTPS URL is required"
    else
        authority="${sqlmap_url#http://}"
        authority="${authority#https://}"
        authority="${authority%%/*}"
        authority="${authority%%\?*}"
        sqlmap_host="${authority%%:*}"

        if [[ "${sqlmap_host,,}" != "${host,,}" ]]; then
            skip_tool "SQLmap" web_results/sqlmap.txt \
                "URL host differs from the initially authorized host"
        else
            read -r -p "POST form data (optional; Enter for GET): " post_data

            sqlmap_args=(
                -u "$sqlmap_url"
                --batch
                --level=1
                --risk=1
                --threads=1
                --timeout=10
                --retries=1
                --output-dir="$PWD/web_results/sqlmap_output"
            )

            if [[ -n "$post_data" ]]; then
                sqlmap_args+=(--data "$post_data")
            fi

            status "[+] SQLmap assessment started..."
            if sqlmap "${sqlmap_args[@]}" > web_results/sqlmap.txt 2>&1; then
                status "[✓] SQLmap process completed. Review saved evidence."
            else
                rc=$?
                status "[!] SQLmap failed (exit $rc). See web_results/sqlmap.txt"
            fi
        fi
    fi
else
    skip_tool "SQLmap" web_results/sqlmap.txt "sqlmap not installed"
fi

# PwnXSS
pwnxss_path=""
if [[ -d /home/kali ]]; then
    pwnxss_path=$(find /home/kali -type f \
        -iname '*pwn*xss*.py' 2>/dev/null | head -n 1)
fi

if [[ -n "$pwnxss_path" ]]; then
    run_tool "PwnXSS" web_results/pwnxss.txt \
        python3 "$pwnxss_path" -u "$web_target"
else
    skip_tool "PwnXSS" web_results/pwnxss.txt "PwnXSS script not found"
fi

# Nuclei
if command -v nuclei >/dev/null 2>&1; then
    run_tool "Nuclei" web_results/nuclei.txt \
        nuclei -u "$web_target" -o web_results/nuclei_findings.txt

    if [[ -f web_results/nuclei_findings.txt ]]; then
        cp web_results/nuclei_findings.txt web_results/nuclei.txt
    fi
else
    skip_tool "Nuclei" web_results/nuclei.txt "nuclei not installed"
fi

status "[✓] Web security assessment completed."

# ============================================================
# 4. COMBINE RESULTS
# ============================================================

status ""
status "[+] Collecting scanner results..."

combined_report="report/cyberguard_results.txt"

{
    cat report/scan_metadata.txt
    echo
    echo "========== EXECUTION STATUS =========="
    cat report/scan_status.txt

    for f in \
        recon_results/whois.txt \
        recon_results/dig.txt \
        recon_results/subfinder.txt \
        recon_results/sublist3r.txt \
        recon_results/sublist3r.log \
        recon_results/theHarvester.txt \
        recon_results/whatweb.txt \
        network_results/nmap_scan.txt \
        network_results/nmap_output.txt \
        web_results/nikto.txt \
        web_results/dirbuster.txt \
        web_results/dirb.log \
        web_results/joomscan.txt \
        web_results/sqlmap.txt \
        web_results/pwnxss.txt \
        web_results/nuclei.txt; do
        if [[ -f "$f" ]]; then
            echo
            echo "========== $f =========="
            cat "$f"
        fi
    done
} > "$combined_report" 2>&1

status "[✓] Combined results saved to $combined_report"

# ============================================================
# 5. AI HTML REPORT
# ============================================================

status ""
status "[+] AI report generation started..."

if [[ ! -f ai_report.py ]]; then
    echo "ai_report.py not found in current directory." > report/ai_report.log
    status "[!] AI report skipped: ai_report.py missing."

elif ! command -v python3 >/dev/null 2>&1; then
    echo "Python 3 is not installed." > report/ai_report.log
    status "[!] AI report skipped: Python 3 missing."

elif [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "GEMINI_API_KEY is not set." > report/ai_report.log
    status "[!] AI report skipped: Gemini API key is missing."
    status '[i] Set it with: export GEMINI_API_KEY="YOUR_API_KEY"'

else
    if python3 ai_report.py "$combined_report" \
        report/cyberguard_AI_Assessment.html \
        > report/ai_report.log 2>&1; then

        if [[ -s report/cyberguard_AI_Assessment.html ]] &&
           grep -qi '</html>' report/cyberguard_AI_Assessment.html; then
            status "[✓] AI HTML report generated successfully."
        else
            rm -f report/cyberguard_AI_Assessment.html
            status "[!] AI report is incomplete; no valid report retained."
            tail -n 12 report/ai_report.log
        fi
    else
        rc=$?
        status "[!] AI report failed (exit $rc)."
        status "[!] Error details from report/ai_report.log:"
        tail -n 12 report/ai_report.log
    fi
fi

# ============================================================
# FINAL SUMMARY
# ============================================================

echo
echo "=================================================="
echo "             CYBERGUARD COMPLETED"
echo "=================================================="
echo "Scanner results: recon_results/ network_results/ web_results/"
echo "Combined report: report/cyberguard_results.txt"

if [[ -s report/cyberguard_AI_Assessment.html ]] &&
   grep -qi '</html>' report/cyberguard_AI_Assessment.html; then
    echo "AI HTML report: report/cyberguard_AI_Assessment.html"
else
    echo "AI HTML report: NOT GENERATED"
    echo "AI error log: report/ai_report.log"
fi

echo "Detailed scanner output is saved in files."
echo "=================================================="
