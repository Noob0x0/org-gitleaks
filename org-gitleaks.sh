#!/usr/bin/env bash

# ==============================
# Configuration
# ==============================
ORG_NAME="$1"                      # e.g. my-org
GITHUB_TOKEN="ghp_1xxx"       # export beforehand
KEYWORDS_FILE="keywords.txt"
WORKDIR="repos"
RESULTS="results"
GITLEAKS_OUT="$RESULTS/gitleaks.json"
FILTERED_OUT="$RESULTS/filtered_findings.txt"

# ==============================
# Checks
# ==============================
if [[ -z "$ORG_NAME" ]]; then
  echo "Usage: $0 <github-org-name>"
  exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Error: GITHUB_TOKEN not set"
  exit 1
fi

if [[ ! -f "$KEYWORDS_FILE" ]]; then
  echo "Error: keywords.txt not found"
  exit 1
fi

mkdir -p "$WORKDIR" "$RESULTS"

# ==============================
# Fetch repositories
# ==============================
echo "[+] Fetching repositories for org: $ORG_NAME"

REPOS=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/orgs/$ORG_NAME/repos?per_page=200" |
  jq -r '.[].clone_url')

# ==============================
# Clone repositories
# ==============================
echo "[+] Cloning repositories"

for repo in $REPOS; do
  name=$(basename "$repo" .git)
  if [[ ! -d "$WORKDIR/$name" ]]; then
    git clone --quiet --depth=1 "$repo" "$WORKDIR/$name"
  fi
done

# ==============================
# Run Gitleaks
# ==============================
echo "[+] Running Gitleaks scan"

gitleaks detect \
  --source="$WORKDIR" \
  --report-format=json \
  --report-path="$GITLEAKS_OUT" \
  --no-git

# ==============================
# Filter using your wordlist
# ==============================
echo "[+] Filtering findings using keyword list"

jq -r '
  .[] |
  "\(.RuleID) | \(.Description) | \(.File) | \(.Match)"
' "$GITLEAKS_OUT" | grep -i -F -f "$KEYWORDS_FILE" > "$FILTERED_OUT"

# ==============================
# Summary
# ==============================
echo
echo "[✓] Scan completed"
echo "Raw Gitleaks report: $GITLEAKS_OUT"
echo "Filtered findings  : $FILTERED_OUT"
echo "Total matches      : $(wc -l < "$FILTERED_OUT")"
