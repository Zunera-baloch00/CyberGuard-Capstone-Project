# CYBERGUARD
### Automated Cybersecurity Assessment Tool

CYBERGUARD is a Bash-based cybersecurity assessment tool designed to automate selected reconnaissance, network scanning, and web security assessment tasks. It collects scanner results and can use the Gemini API to generate a professional HTML assessment report.

> **Disclaimer:** Use this tool only on systems you own or have explicit authorization to test. Unauthorized security scanning may violate laws or service policies.

## Features

- **Reconnaissance:** WHOIS, DNS records, Subfinder, Sublist3r, theHarvester, and WhatWeb.
- **Network Scanning:** Nmap service and version detection.
- **Web Security Assessment:** Nikto, DIRB, JoomScan, SQLmap, PwnXSS, and Nuclei, depending on installation and prerequisites.
- **Automated Evidence Collection:** Combines scan metadata, execution statuses, and scanner output.
- **AI HTML Reporting:** Uses the Gemini API to analyze collected evidence and generate a standalone HTML report.
- **Fallback Reporting:** If AI report generation fails, a clearly labelled HTML page containing scanner evidence is created.

Automated results should always be reviewed manually. A scanner finding does not automatically prove that a vulnerability is exploitable.

## Technologies Used

- Bash
- Python 3
- Kali Linux
- Nmap
- WHOIS and DNS utilities
- Web security assessment tools
- Google Gemini API
- HTML and embedded CSS

## Project Structure

```text
CYBERGUARD/
├── CyberGuard.sh
├── ai_report.py
├── recon_results/
├── network_results/
├── web_results/
│   └── sqlmap_output/
└── report/
    ├── scan_metadata.txt
    ├── scan_status.txt
    ├── cyberguard_results.txt
    ├── ai_report.log
    └── cyberguard_AI_Assessment.html
```

The result directories and report files are created during execution.

## Requirements

- Kali Linux or a compatible Linux environment
- Bash
- Python 3
- Internet connectivity for applicable scanning tools and Gemini API reporting
- The scanner tools required for the assessments you want to run

### Install Common Tools

Open the Kali Linux terminal and run:

```bash
sudo apt update
sudo apt install -y git python3 whois dnsutils nmap whatweb nikto dirb sqlmap
```

Other tools, including Subfinder, Sublist3r, theHarvester, JoomScan, PwnXSS, and Nuclei, may require separate installation.

Check the availability of common tools:

```bash
command -v whois dig nmap whatweb nikto dirb sqlmap
```

A missing tool may cause that assessment to be skipped. Follow each tool's official installation instructions for your Kali version.

## Download the Project from GitHub

Open a terminal and clone the repository:

```bash
git clone https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
```

Replace `YOUR-USERNAME` and `YOUR-REPOSITORY` with the actual GitHub username and repository name.

Enter the project directory:

```bash
cd YOUR-REPOSITORY
```

Check the files:

```bash
ls
```

Make sure `CyberGuard.sh` and `ai_report.py` are present.

## Configure the Gemini API

CYBERGUARD's current report generator uses the Google Gemini API.

### 1. Create an API Key

1. Visit [Google AI Studio](https://aistudio.google.com/).
2. Sign in with your Google account.
3. Open the API keys section.
4. Create or select an API key for a project with Gemini API access.

### 2. Set the API Key

In the Kali terminal, run:

```bash
export GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
```

Replace `YOUR_GEMINI_API_KEY` with your actual key.

**Security warning:** Never publish your API key in a GitHub repository, source code, screenshots, or public messages.

Check whether the variable is set without displaying the secret:

```bash
echo ${#GEMINI_API_KEY}
```

A value greater than zero means the variable contains a value. It does not guarantee that the key is valid.

### 3. Configure the Model

The current Python script defaults to `gemini-3.6-flash`.

You can set the model explicitly:

```bash
export GEMINI_MODEL="gemini-3.6-flash"
```

Use a model that is available to your Gemini API project.

A new API key in the same project does not necessarily increase its quota.

## Run CYBERGUARD

From the project directory, run:

```bash
chmod +x CyberGuard.sh
./CyberGuard.sh
```

### Enter a Target

The program asks:

```text
Enter authorized domain, IP, or URL:
```

Enter a domain, IP address, or URL that you are authorized to assess.

For example, the input format may be:

```text
example.com
192.0.2.10
https://example.com
```

These examples illustrate input formats only. Use an authorized target for actual testing.

The program then asks you to confirm authorization. Type:

```text
yes
```

The scan will exit if authorization is not confirmed.

### Directory Discovery

When prompted for a wordlist path, enter a valid wordlist path or press Enter to use the default:

```text
/usr/share/dirb/wordlists/common.txt
```

The directory scan will be skipped if DIRB or the selected wordlist is unavailable.

### SQLmap Assessment

The program asks for an optional SQLmap test URL.

Enter a URL from an authorized lab environment that contains a relevant query parameter, or press Enter to skip.

For example, a deliberately vulnerable local lab might use a URL like:

```text
http://127.0.0.1/DVWA/vulnerabilities/sqli/?id=1
```

The example works only if the relevant lab is installed and configured.

Optional POST form data can also be entered when prompted. SQLmap is skipped if the supplied URL's host differs from the initially authorized host.

## AI HTML Report Generation

After the scanners finish, CYBERGUARD combines the results into:

```text
report/cyberguard_results.txt
```

The Python report generator reads this evidence, reduces the input size, and sends it to Gemini for analysis. The intended report includes an executive summary, evidence-based findings, severity, impact, remediation, and a conclusion.

The generated report is saved as:

```text
report/cyberguard_AI_Assessment.html
```

To open it in Kali Linux:

```bash
xdg-open report/cyberguard_AI_Assessment.html
```

### Important: AI Report vs. Fallback Report

If Gemini cannot generate a complete report, the Python script creates a fallback HTML report containing scanner evidence.

The fallback page explicitly states that it is **not AI-generated**. Check the report banner and log before treating the output as an AI assessment.

The log is saved at:

```text
report/ai_report.log
```

## Run the Report Generator Separately

If scanner results already exist, you can run the report generator without rerunning the entire assessment:

```bash
python3 ai_report.py report/cyberguard_results.txt report/cyberguard_AI_Assessment.html
```

Make sure `GEMINI_API_KEY` is set in the same terminal.

## Output Files

| File or Directory | Purpose |
|---|---|
| `recon_results/` | Reconnaissance output |
| `network_results/` | Nmap output |
| `web_results/` | Web assessment output |
| `report/scan_metadata.txt` | Target and assessment metadata |
| `report/scan_status.txt` | Tool execution statuses |
| `report/cyberguard_results.txt` | Combined scanner evidence |
| `report/ai_report.log` | AI report generation log |
| `report/cyberguard_AI_Assessment.html` | AI report or labelled fallback |

## Troubleshooting

### API Key Not Set

If the program reports that `GEMINI_API_KEY` is missing, set it in the current terminal:

```bash
export GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
```

### HTTP 401 — Invalid API Key

Check that the key was copied correctly, has not been revoked, and belongs to a project with Gemini API access. Never share the key publicly.

### HTTP 429 — Quota or Rate Limit Exceeded

This can happen when a request, input-token, daily usage, or another project quota exceeds its limit.

1. Check [Gemini Usage](https://aistudio.google.com/usage).
2. Check [Gemini Rate Limits](https://aistudio.google.com/rate-limit).
3. Wait for the relevant quota window to reset.
4. Consider reducing the scanner evidence sent to the AI.
5. Review available quota and billing options if needed.

Creating another key in the same project does not necessarily remove project-level quota restrictions.

### A Scanner Was Skipped

A scanner may be missing, unavailable in `PATH`, or unable to run because a required wordlist or prerequisite is missing. Check its output file and status messages.

### HTML Report Was Not Generated Successfully

Read `report/ai_report.log`. If the HTML file contains a fallback warning, it must not be described as an AI-generated assessment.

## Security and Responsible Use

- Obtain explicit authorization before scanning.
- Use a local training lab for SQL injection and web security exercises.
- Keep API keys private and out of version control.
- Protect reports because they may contain sensitive system information.
- Verify scanner findings before making security claims.
- Automated assessment tools cannot guarantee that a system is secure.

## License

Add an appropriate license file before distributing this project publicly. Without a license, others may not have explicit permission to reuse, modify, or redistribute the code.
