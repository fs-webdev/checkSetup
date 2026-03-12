#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# FamilySearch Frontier Onboarding Setup Script
# ─────────────────────────────────────────────────────────────────────────────

# ANSI Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Print helpers ─────────────────────────────────────────────────────────────
print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│  $1${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────────────┘${RESET}"
}

print_done() { echo -e "  ${GREEN}✔${RESET}  $1"; }
print_skip() { echo -e "  ${DIM}↷  $1 (already done)${RESET}"; }
print_warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
print_info() { echo -e "  ${CYAN}ℹ${RESET}  $1"; }
print_error() { echo -e "  ${RED}✖${RESET}  $1"; }
print_prompt() { echo -en "  ${BOLD}▶${RESET}  $1"; }
print_step() { echo -e "  ${DIM}→${RESET}  $1"; }

# ── State tracking for summary ────────────────────────────────────────────────
PHASES_COMPLETED=()
PHASES_SKIPPED=()

# ── Collected inputs ──────────────────────────────────────────────────────────
GIT_NAME=""
GIT_EMAIL=""
GITHUB_TOKEN=""
ARTIFACTORY_EMAIL=""
ARTIFACTORY_TOKEN=""

# =============================================================================
# GUARDS & UTILITIES
# =============================================================================

check_macos() {
  if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This script is for macOS only."
    exit 1
  fi
}

pause_for_external_action() {
  local message="$1"
  echo ""
  print_warn "$message"
  echo ""
  print_prompt "Press [Enter] when done (or type 'skip' to skip): "
  local response
  read -r response
  if [[ "$response" == "skip" ]]; then
    return 1
  fi
  return 0
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  if [[ "$default" == "y" ]]; then
    print_prompt "${prompt} [Y/n]: "
  else
    print_prompt "${prompt} [y/N]: "
  fi
  local response
  read -r response
  response="${response:-$default}"
  [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# BANNER
# =============================================================================

print_banner() {
  echo ""
  echo -e "${BOLD}${CYAN}╔═════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║          FamilySearch Frontier Onboarding Setup                     ║${RESET}"
  echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  This script will configure your Mac for Frontier development."
  echo -e "  Some steps require external actions (GitHub, Artifactory) and will"
  echo -e "  pause so you can complete them in a browser."
  echo ""
  echo -e "  ${DIM}You can re-run this script at any time — completed steps are skipped.${RESET}"
  echo ""
}

# =============================================================================
# PHASE 0: COLLECT INPUTS UPFRONT
# =============================================================================

collect_inputs() {
  print_header "Pre-flight: Collecting Configuration"

  # Git name
  local existing_name
  existing_name="$(git config --global user.name 2>/dev/null || true)"
  if [[ -n "$existing_name" ]]; then
    print_skip "git user.name already set to \"${existing_name}\""
    GIT_NAME="$existing_name"
  else
    print_prompt "Your full name (for git commits): "
    read -r GIT_NAME
    while [[ -z "$GIT_NAME" ]]; do
      print_warn "Name cannot be empty."
      print_prompt "Your full name: "
      read -r GIT_NAME
    done
  fi

  # Git email
  local existing_email
  existing_email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$existing_email" ]]; then
    print_skip "git user.email already set to \"${existing_email}\""
    GIT_EMAIL="$existing_email"
  else
    print_prompt "Your email associated with GitHub (for git commits): "
    read -r GIT_EMAIL
    while [[ -z "$GIT_EMAIL" ]]; do
      print_warn "Email cannot be empty."
      print_prompt "Your GitHub email: "
      read -r GIT_EMAIL
    done
  fi

  # GitHub token (skip if .netrc already has it)
  if grep -q "machine github.com" "$HOME/.netrc" 2>/dev/null; then
    print_skip ".netrc already has a github.com entry — skipping token prompt"
  else
    echo ""
    print_info "You will need a GitHub Personal Access Token (classic) with 'repo' scope."
    print_info "Generate one at: https://github.com/settings/tokens"
    print_info "After generating, authorize it for the 'fs-webdev' and 'LDS-Church' orgs (Configure SSO)."
    echo ""
    print_prompt "GitHub Personal Access Token (input hidden): "
    read -rs GITHUB_TOKEN
    echo ""
    while [[ -z "$GITHUB_TOKEN" ]]; do
      print_warn "Token cannot be empty."
      print_prompt "GitHub Personal Access Token: "
      read -rs GITHUB_TOKEN
      echo ""
    done
  fi

  print_done "Inputs collected"
}

# =============================================================================
# PHASE 1: XCODE COMMAND LINE TOOLS
# =============================================================================

phase_1_xcode() {
  print_header "Phase 1: Xcode Command Line Tools"

  if xcode-select -p &>/dev/null; then
    print_skip "Xcode CLT already installed ($(xcode-select -p))"
    PHASES_SKIPPED+=("Phase 1: Xcode CLT")
    return 0
  fi

  print_step "Triggering Xcode CLT install dialog..."
  xcode-select --install 2>/dev/null || true

  print_info "A system dialog has appeared asking you to install the Xcode Command Line Tools."
  print_info "Click 'Install' and wait for it to complete before pressing Enter."
  echo ""

  # Poll until done
  local max_wait=600 # 10 minutes
  local waited=0
  local interval=10
  while ! xcode-select -p &>/dev/null; do
    if ((waited >= max_wait)); then
      print_error "Timed out waiting for Xcode CLT. Re-run the script after installation completes."
      exit 1
    fi
    echo -en "\r  ${DIM}Waiting for Xcode CLT installation... (${waited}s)${RESET}"
    sleep "$interval"
    waited=$((waited + interval))
  done
  echo ""

  print_done "Xcode Command Line Tools installed"
  PHASES_COMPLETED+=("Phase 1: Xcode CLT")
}

# =============================================================================
# PHASE 2: GITHUB ACCESS (DEFERRED — USER ACTION REQUIRED)
# =============================================================================

phase_2_github_access() {
  print_header "Phase 2: GitHub Organization Access"

  echo ""
  echo -e "  ${BOLD}This phase requires actions in your browser. Steps to complete:${RESET}"
  echo ""
  echo -e "  ${BOLD}1.${RESET} Create a GitHub account at ${CYAN}https://github.com${RESET} (if you don't have one)"
  echo -e "  ${BOLD}2.${RESET} Enable two-factor authentication (2FA) on your GitHub account"
  echo -e "  ${BOLD}3.${RESET} Request org membership via ${CYAN}https://tools.fsdpt.org${RESET}"
  echo -e "      → Look for the GitHub org request tool and request access to both:"
  echo -e "        • ${BOLD}fs-webdev${RESET}"
  echo -e "        • ${BOLD}LDS-Church${RESET}"
  echo -e "  ${BOLD}4.${RESET} Accept the invitation email from GitHub"
  echo ""
  echo -e "  ${DIM}Note: Org membership requests require manager approval and may take a few minutes.${RESET}"
  echo ""

  if ! pause_for_external_action "Complete GitHub setup (account, 2FA, org membership, invitation acceptance) then press Enter"; then
    print_warn "Skipping GitHub access phase — some later steps may fail without org membership"
    PHASES_SKIPPED+=("Phase 2: GitHub Access (skipped by user)")
    return 0
  fi

  echo ""
  echo -e "  ${BOLD}Next: Generate a Personal Access Token${RESET}"
  echo ""
  echo -e "  ${BOLD}5.${RESET} Go to ${CYAN}https://github.com/settings/tokens${RESET}"
  echo -e "  ${BOLD}6.${RESET} Click 'Generate new token' → 'Generate new token (classic)'"
  echo -e "  ${BOLD}7.${RESET} Give it a name (e.g., 'FamilySearch Dev'), set expiration, check the ${BOLD}repo${RESET} scope"
  echo -e "  ${BOLD}8.${RESET} Click 'Generate token' and copy the token value"
  echo -e "  ${BOLD}9.${RESET} Back on the tokens list, click 'Configure SSO' next to your token"
  echo -e "      → Authorize for ${BOLD}fs-webdev${RESET} and ${BOLD}LDS-Church${RESET}"
  echo ""

  # If we didn't collect a token yet (netrc already existed), collect it now
  if [[ -z "$GITHUB_TOKEN" ]]; then
    if ! grep -q "machine github.com" "$HOME/.netrc" 2>/dev/null; then
      print_prompt "Paste your GitHub Personal Access Token (input hidden): "
      read -rs GITHUB_TOKEN
      echo ""
    fi
  fi

  print_done "GitHub access phase complete"
  PHASES_COMPLETED+=("Phase 2: GitHub Access")
}

# =============================================================================
# PHASE 3: GIT CONFIGURATION
# =============================================================================

phase_3_git_config() {
  print_header "Phase 3: Git Configuration"

  # user.name
  local existing_name
  existing_name="$(git config --global user.name 2>/dev/null || true)"
  if [[ -n "$existing_name" ]]; then
    print_skip "git user.name = \"${existing_name}\""
  else
    git config --global user.name "$GIT_NAME"
    print_done "git user.name set to \"${GIT_NAME}\""
  fi

  # user.email
  local existing_email
  existing_email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$existing_email" ]]; then
    print_skip "git user.email = \"${existing_email}\""
  else
    git config --global user.email "$GIT_EMAIL"
    print_done "git user.email set to \"${GIT_EMAIL}\""
  fi

  # url rewrite: git:// → https://
  local existing_rewrite
  existing_rewrite="$(git config --global url."https://".insteadOf 2>/dev/null || true)"
  if [[ "$existing_rewrite" == "git://" ]]; then
    print_skip "git url rewrite (git:// → https://) already configured"
  else
    git config --global url."https://".insteadOf "git://"
    print_done "git url rewrite configured (git:// → https://)"
  fi

  # ~/.netrc for GitHub
  if grep -q "machine github.com" "$HOME/.netrc" 2>/dev/null; then
    print_skip "~/.netrc already has github.com entry"
  else
    if [[ -z "$GITHUB_TOKEN" ]]; then
      print_warn "No GitHub token available — skipping .netrc write"
    else
      {
        echo ""
        echo "machine github.com"
        echo "  login $GITHUB_TOKEN"
      } >>"$HOME/.netrc"
      chmod 600 "$HOME/.netrc"
      print_done "~/.netrc updated with github.com credentials"
    fi
  fi

  print_done "Git configuration complete"
  PHASES_COMPLETED+=("Phase 3: Git Config")
}

# =============================================================================
# PHASE 4: NVM AND NODE
# =============================================================================

phase_4_nvm_and_node() {
  print_header "Phase 4: nvm and Node.js"

  # Skip entirely if fnm is already managing Node versions
  if command -v fnm &>/dev/null; then
    print_skip "fnm detected ($(fnm --version 2>/dev/null || echo 'version unknown')) — skipping nvm setup"
    PHASES_SKIPPED+=("Phase 4: nvm + Node 24 (fnm already present)")
    return 0
  fi

  # Install nvm
  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    print_skip "nvm already installed"
  else
    print_step "Installing nvm v0.40.3..."
    set +e
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    local curl_exit=$?
    set -e
    if ((curl_exit != 0)); then
      print_error "nvm installation failed (exit code ${curl_exit})"
      exit 1
    fi
    print_done "nvm installed"
  fi

  # Source nvm into current session
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

  if ! command -v nvm &>/dev/null; then
    print_error "nvm could not be sourced into this session. Try restarting your terminal and re-running."
    exit 1
  fi

  # Install Node 24
  set +e
  local node24_installed
  node24_installed="$(nvm ls 24 2>/dev/null | grep -c "v24" || true)"
  set -e

  if ((node24_installed > 0)); then
    print_skip "Node 24 already installed"
  else
    print_step "Installing Node 24..."
    nvm install 24
    print_done "Node 24 installed"
  fi

  local current_default
  current_default="$(nvm alias default 2>/dev/null | grep -o 'v24\.[^ ]*' || true)"
  if [[ -n "$current_default" ]]; then
    print_skip "nvm default already set to Node 24 (${current_default})"
  else
    nvm alias default 24 &>/dev/null
    print_done "Node 24 set as default"
  fi

  # Add nvm auto-switch hook to ~/.zshrc
  local zshrc="$HOME/.zshrc"
  local marker="# nvm auto-switch: add-zsh-hook chpwd load-nvmrc"

  if grep -q "add-zsh-hook chpwd load-nvmrc" "$zshrc" 2>/dev/null; then
    print_skip "nvm auto-switch hook already in ~/.zshrc"
  else
    cat >>"$zshrc" <<'ZSHRC_BLOCK'

# nvm auto-switch: add-zsh-hook chpwd load-nvmrc
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

autoload -U add-zsh-hook
load-nvmrc() {
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc)"
  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")
    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
      nvm use
    fi
  elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc
ZSHRC_BLOCK
    print_done "nvm auto-switch hook added to ~/.zshrc"
  fi

  PHASES_COMPLETED+=("Phase 4: nvm + Node 24")
}

# =============================================================================
# PHASE 5: ARTIFACTORY
# =============================================================================

phase_5_artifactory() {
  print_header "Phase 5: Artifactory npm Registry"

  # Check if already configured
  if grep -q "familysearch.jfrog.io" "$HOME/.npmrc" 2>/dev/null; then
    print_skip "~/.npmrc already has Artifactory configuration"
    PHASES_SKIPPED+=("Phase 5: Artifactory")
    _verify_artifactory
    return 0
  fi

  # Request access first
  echo ""
  echo -e "  ${BOLD}Artifactory access must be requested before we can configure it.${RESET}"
  echo ""
  echo -e "  ${BOLD}1.${RESET} Go to ${CYAN}https://tools.fsdpt.org${RESET}"
  echo -e "  ${BOLD}2.${RESET} Find the Artifactory access request tool"
  echo -e "  ${BOLD}3.${RESET} Submit a request for npm registry access"
  echo -e "  ${BOLD}4.${RESET} Wait for approval (typically ~10 minutes)"
  echo -e "  ${BOLD}5.${RESET} Once approved, log in to ${CYAN}https://familysearch.jfrog.io${RESET}"
  echo -e "  ${BOLD}6.${RESET} Click your username (top right) → 'Edit Profile'"
  echo -e "  ${BOLD}7.${RESET} Generate an 'Identity Token' and copy it"
  echo ""

  if ! pause_for_external_action "Request Artifactory access, wait for approval, then generate an Identity Token"; then
    print_warn "Skipping Artifactory phase"
    PHASES_SKIPPED+=("Phase 5: Artifactory (skipped by user)")
    return 0
  fi

  # Collect Artifactory credentials just-in-time
  echo ""
  print_prompt "Your Artifactory email (usually your work email): "
  read -r ARTIFACTORY_EMAIL
  while [[ -z "$ARTIFACTORY_EMAIL" ]]; do
    print_warn "Email cannot be empty."
    print_prompt "Artifactory email: "
    read -r ARTIFACTORY_EMAIL
  done

  print_prompt "Artifactory Identity Token (input hidden): "
  read -rs ARTIFACTORY_TOKEN
  echo ""
  while [[ -z "$ARTIFACTORY_TOKEN" ]]; do
    print_warn "Token cannot be empty."
    print_prompt "Artifactory Identity Token: "
    read -rs ARTIFACTORY_TOKEN
    echo ""
  done

  # Back up existing .npmrc
  if [[ -f "$HOME/.npmrc" ]]; then
    local backup="$HOME/.npmrc.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.npmrc" "$backup"
    print_info "Backed up existing ~/.npmrc to ${backup}"
  fi

  # Fetch Artifactory .npmrc config
  print_step "Fetching Artifactory npm configuration..."
  set +e
  local curl_output
  curl_output="$(curl -su "${ARTIFACTORY_EMAIL}:${ARTIFACTORY_TOKEN}" \
    "https://familysearch.jfrog.io/artifactory/api/npm/npm-virtual/auth/fs" 2>&1)"
  local curl_exit=$?
  set -e

  if ((curl_exit != 0)); then
    print_error "Failed to fetch Artifactory config (curl exit: ${curl_exit})"
    print_error "Check your email and token, then re-run the script."
    exit 1
  fi

  # Verify the response contains an auth token
  if ! echo "$curl_output" | grep -q "_authToken"; then
    print_error "Artifactory response did not contain an auth token."
    print_error "Response: ${curl_output}"
    print_error "Check your credentials and try again."
    exit 1
  fi

  # Write to .npmrc
  echo "$curl_output" >>"$HOME/.npmrc"

  # Confirm it was written
  if ! grep -q "familysearch.jfrog.io" "$HOME/.npmrc"; then
    print_error "Failed to write Artifactory config to ~/.npmrc"
    exit 1
  fi

  print_done "~/.npmrc updated with Artifactory configuration"

  _verify_artifactory

  PHASES_COMPLETED+=("Phase 5: Artifactory")
}

_verify_artifactory() {
  print_step "Verifying Artifactory setup with npx fs-webdev/checkSetup..."
  echo ""
  set +e
  npx fs-webdev/checkSetup
  local check_exit=$?
  set -e
  echo ""
  if ((check_exit == 0)); then
    print_done "Artifactory verification passed"
  else
    print_warn "Artifactory verification returned exit code ${check_exit} — you may need to revisit credentials"
  fi
}

# =============================================================================
# PHASE 6: FRONTIER CLI
# =============================================================================

phase_6_frontier_cli() {
  print_header "Phase 6: Frontier CLI (@fs/fr-cli)"

  # Ensure nvm is sourced in this session
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

  # Install fr-cli globally
  if command -v fr &>/dev/null; then
    print_skip "fr CLI already installed ($(fr --version 2>/dev/null || echo 'version unknown'))"
    PHASES_SKIPPED+=("Phase 6: Frontier CLI")
  else
    print_step "Installing @fs/fr-cli globally..."
    npm i -g @fs/fr-cli
    print_done "@fs/fr-cli installed"
    PHASES_COMPLETED+=("Phase 6: Frontier CLI")
  fi

  # Add to nvm default-packages so it reinstalls with future Node versions
  local default_packages="$HOME/.nvm/default-packages"
  if [[ -f "$default_packages" ]] && grep -q "@fs/fr-cli" "$default_packages"; then
    print_skip "@fs/fr-cli already in ~/.nvm/default-packages"
  else
    echo "@fs/fr-cli" >>"$default_packages"
    print_done "@fs/fr-cli added to ~/.nvm/default-packages"
  fi
}

# =============================================================================
# PHASE 7: HOMEBREW
# =============================================================================

phase_7_homebrew() {
  print_header "Phase 7: Homebrew"

  if command -v brew &>/dev/null; then
    print_skip "Homebrew already installed ($(brew --version | head -1))"
    PHASES_SKIPPED+=("Phase 7: Homebrew")
    return 0
  fi

  print_step "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Apple Silicon path fix
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    print_done "Homebrew (Apple Silicon) path configured for this session"
    # Persist to .zshrc
    local zshrc="$HOME/.zshrc"
    if ! grep -q 'opt/homebrew/bin/brew shellenv' "$zshrc" 2>/dev/null; then
      echo "" >>"$zshrc"
      echo '# Homebrew (Apple Silicon)' >>"$zshrc"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$zshrc"
      print_done "Homebrew path added to ~/.zshrc"
    fi
  fi

  print_done "Homebrew installed"
  PHASES_COMPLETED+=("Phase 7: Homebrew")
}

# =============================================================================
# PHASE 8: GITHUB CLI TOOL
# =============================================================================


phase_8_github_cli() {
  print_header "Phase 8: GitHub CLI Tool (gh)"

  # Homebrew is required for GitHub CLI installation
  if ! command -v brew &>/dev/null; then
    print_warn "Homebrew not found — cannot install GitHub CLI. This indicates Phase 7 may have failed."
    PHASES_SKIPPED+=("Phase 8: GitHub CLI (Homebrew not found)")
    return 0
  fi

  # Check if gh is already installed
  if command -v gh &>/dev/null; then
    print_skip "GitHub CLI (gh) already installed ($(gh --version | head -1))"
    PHASES_SKIPPED+=("Phase 8: GitHub CLI")
    return 0
  fi

  print_step "Installing GitHub CLI..."
  brew install gh
  print_done "GitHub CLI installed"
  PHASES_COMPLETED+=("Phase 8: GitHub CLI")
}

# =============================================================================
# PHASE 9: OPTIONAL TOOLS
# =============================================================================

phase_9_optional() {
  print_header "Phase 9: Optional Tools"

  # ── Watchman ─────────────────────────────────────────────────────────────
  if command -v watchman &>/dev/null; then
    print_skip "Watchman already installed ($(watchman --version 2>/dev/null || echo 'version unknown'))"
    PHASES_SKIPPED+=("Phase 9: Watchman")
  else
    echo ""
    print_info "Watchman provides fast file-watching for Metro bundler (React Native / Frontier)."
    if ask_yes_no "Install Watchman via Homebrew?"; then
      if ! command -v brew &>/dev/null; then
        print_warn "Homebrew not found — cannot install Watchman. Install Homebrew first."
        PHASES_SKIPPED+=("Phase 9: Watchman")
      else
        print_step "Installing Watchman..."
        brew install watchman
        print_done "Watchman installed"
        echo ""
        print_warn "Watchman may need Full Disk Access to work properly."
        print_info "If you see permission errors, go to:"
        print_info "  System Settings → Privacy & Security → Full Disk Access"
        print_info "  and enable Watchman (or your terminal app)."
        PHASES_COMPLETED+=("Phase 9: Watchman")
      fi
    else
      print_info "Skipping Watchman installation"
      PHASES_SKIPPED+=("Phase 9: Watchman (declined)")
    fi
  fi
}

# =============================================================================
# SUMMARY
# =============================================================================

print_summary() {
  echo ""
  echo -e "${BOLD}${CYAN}╔═════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║                        Setup Complete                               ║${RESET}"
  echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  if ((${#PHASES_COMPLETED[@]} > 0)); then
    echo -e "  ${GREEN}${BOLD}Completed this run:${RESET}"
    for phase in "${PHASES_COMPLETED[@]}"; do
      echo -e "  ${GREEN}✔${RESET}  $phase"
    done
    echo ""
  fi

  if ((${#PHASES_SKIPPED[@]} > 0)); then
    echo -e "  ${DIM}${BOLD}Already done / skipped:${RESET}"
    for phase in "${PHASES_SKIPPED[@]}"; do
      echo -e "  ${DIM}↷  $phase${RESET}"
    done
    echo ""
  fi

  echo -e "  ${BOLD}Quick verification:${RESET}"
  echo -e "  ${DIM}node -v          →${RESET} should show v24.x"
  echo -e "  ${DIM}fr --version     →${RESET} should show Frontier CLI version"
  echo -e "  ${DIM}git config --global user.name${RESET}  →  should show your name"
  echo ""

  echo -e "  ${YELLOW}${BOLD}⚠  Reload your shell to apply all changes:${RESET}"
  echo ""
  echo -e "    ${BOLD}source ~/.zshrc${RESET}"
  echo -e "  ${DIM}or restart your terminal${RESET}"
  echo ""

  echo -e "  ${BOLD}Next steps by role:${RESET}"
  echo ""
  echo -e "  ${CYAN}Designers:${RESET}"
  echo -e "    claude plugin add ux-playground"
  echo ""
  echo -e "  ${CYAN}Developers:${RESET}"
  echo -e "    Visit the Frontier docs for project-specific setup:"
  echo -e "    ${CYAN}https://frontier.familysearch.org/docs${RESET}"
  echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
  check_macos
  print_banner
  collect_inputs
  phase_1_xcode
  phase_2_github_access
  phase_3_git_config
  phase_4_nvm_and_node
  phase_5_artifactory
  phase_6_frontier_cli
  phase_7_homebrew
  phase_8_github_cli
  phase_9_optional
  print_summary
}

main "$@"
