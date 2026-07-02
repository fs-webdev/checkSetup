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
  echo -e "  wait for you to complete them in a browser."
  echo ""
  echo -e "  ${DIM}You can re-run this script at any time — completed steps are skipped.${RESET}"
  echo ""
}

# =============================================================================
# PHASE 0: COLLECT GIT CONFIGURATION
# =============================================================================

collect_inputs() {
  print_header "Pre-flight: Collecting Configuration"

  # Git name
  local existing_name
  existing_name="$(git config --global user.name 2>/dev/null || true)"
  if [[ -n "$existing_name" ]]; then
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

  print_done "Inputs collected"

  # ── Preflight: Request all portal permissions upfront ─────────────────────
  echo ""
  echo -e "  ${BOLD}Before continuing, you need permissions from the Engineering Tools Portal.${RESET}"
  echo -e "  ${BOLD}Request both of the following at the same time so you only wait for manager approval once.${RESET}"
  echo ""
  echo -e "  ${BOLD}1.${RESET} Go to ${CYAN}https://tools.fsdpt.org/portal/userManagement/requestAccess${RESET}"
  echo -e "  ${BOLD}2.${RESET} Search for and request ${BOLD}GitHub${RESET} permissions:"
  echo -e "        • ${BOLD}Github - fs-webdev - Member${RESET}"
  echo -e "        • ${BOLD}Github - fs-eng - Member${RESET} (if you are a developer)"
  echo -e "  ${BOLD}3.${RESET} Search for and request ${BOLD}Artifactory${RESET} permissions:"
  echo -e "        • ${BOLD}Artifactory - User${RESET}"
  echo -e "  ${BOLD}4.${RESET} Ask your manager to approve all requests"
  echo -e "  ${BOLD}5.${RESET} Wait for manager approval before continuing"
  echo ""
  echo -e "  ${DIM}Requesting both now avoids having to wait for manager approval twice later.${RESET}"
  echo ""

  pause_for_external_action "Request both GitHub and Artifactory permissions in the portal, wait for manager approval, then press Enter" || true

  print_done "Portal permissions requested"
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
  echo -e "  ${BOLD}3.${RESET} Accept the invitation email from GitHub once your manager has approved your request"
  echo ""
  echo -e "  ${DIM}Note: GitHub org membership was requested during preflight. If not yet approved, wait for your manager before continuing.${RESET}"
  echo ""

  if ! pause_for_external_action "Complete GitHub setup (account, 2FA, accept invitation email) then press Enter"; then
    print_warn "Skipping GitHub access phase — some later steps may fail without org membership"
    PHASES_SKIPPED+=("Phase 2: GitHub Access (skipped by user)")
    return 0
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
  if [[ "$existing_rewrite" != "git://" ]]; then
    git config --global url."https://".insteadOf "git://"
    print_done "git url rewrite configured (git:// → https://)"
  fi

  print_info "GitHub authentication is handled by the GitHub CLI (gh) in a later phase — no"
  print_info "personal access token or ~/.netrc file is needed."

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
    print_step "Installing nvm v0.40.4..."
    set +e
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
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
  local current_registry
  current_registry="$(npm config get registry 2>/dev/null || true)"
  if [[ "$current_registry" == *"familysearch.jfrog.io"* ]]; then
    print_skip "Artifactory registry already configured"
    PHASES_SKIPPED+=("Phase 5: Artifactory")
    return 0
  fi

  echo ""
  echo -e "  ${DIM}Artifactory access was requested during preflight. If not yet approved, wait for your manager before continuing.${RESET}"
  echo ""

  # Set registry using npm config
  npm config set registry "https://familysearch.jfrog.io/artifactory/api/npm/fs-npm-prod-virtual/"

  # Verify registry was set correctly
  local configured_registry
  configured_registry="$(npm config get registry)"
  if [[ "$configured_registry" != *"familysearch.jfrog.io"* ]]; then
    print_error "Failed to configure Artifactory registry. Current registry: ${configured_registry}"
    exit 1
  fi
  print_done "Artifactory registry configured"

  # Authenticate with npm login
  echo ""
  echo -e "  ${BOLD}npm login will open your browser for SAML SSO authentication.${RESET}"
  echo -e "  ${DIM}Complete the login flow in your browser, then return here and press Enter.${RESET}"
  echo ""

  npm login

  # Verify it worked
  if npm view @fs/check-setup version &>/dev/null; then
    print_done "Artifactory authentication successful"
    PHASES_COMPLETED+=("Phase 5: Artifactory")
  else
    print_error "Artifactory authentication failed. Please try again."
    exit 1
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
    print_skip "Homebrew already installed ($(brew --version 2>/dev/null | head -1 || echo 'version unknown'))"
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

  # Verify Homebrew is now available on PATH
  if ! command -v brew &>/dev/null; then
    print_error "Homebrew installation completed but 'brew' is not on your PATH."
    print_info "You may need to restart your shell or run: eval \"\$(/opt/homebrew/bin/brew shellenv)\""
    exit 1
  fi

  print_done "Homebrew installed"
  PHASES_COMPLETED+=("Phase 7: Homebrew")
}

# =============================================================================
# PHASE 8: GITHUB CLI TOOL & AUTHENTICATION
# =============================================================================

# Authenticate git with GitHub using the gh CLI OAuth web flow.
# This replaces the old personal access token + ~/.netrc approach.
gh_auth_login() {
  if ! command -v gh &>/dev/null; then
    print_warn "gh CLI not available — cannot authenticate with GitHub."
    return 0
  fi

  if gh auth status &>/dev/null; then
    print_skip "GitHub CLI already authenticated"
    return 0
  fi

  echo ""
  print_info "Authenticating with GitHub via the gh CLI (OAuth web flow)."
  print_info "A browser window will open. When prompted, choose:"
  echo -e "        • ${BOLD}GitHub.com${RESET}"
  echo -e "        • ${BOLD}HTTPS${RESET} for the preferred protocol"
  echo -e "        • ${BOLD}Yes${RESET} to authenticate Git with your GitHub credentials"
  echo -e "        • ${BOLD}Login with a web browser${RESET}, then paste the one-time code"
  echo ""
  print_info "Prefer SSH keys instead? See the GitHub Access guide:"
  print_info "  ${CYAN}https://icseng.atlassian.net/wiki/spaces/DPT/pages/2352611334${RESET}"
  echo ""

  set +e
  gh auth login --hostname github.com --git-protocol https --web
  local login_exit=$?
  set -e
  if ((login_exit != 0)); then
    print_warn "gh auth login did not complete — you can re-run 'gh auth login' at any time."
    return 0
  fi

  # Configure gh as the git credential helper for HTTPS operations
  gh auth setup-git 2>/dev/null || true

  if gh auth status &>/dev/null; then
    print_done "GitHub CLI authenticated"
  else
    print_warn "GitHub authentication not detected — run 'gh auth login' manually if git access fails."
  fi
}

phase_8_github_cli() {
  print_header "Phase 8: GitHub CLI Tool (gh) & Authentication"

  # Check if gh is already installed
  if command -v gh &>/dev/null; then
    print_skip "GitHub CLI (gh) already installed ($(gh --version 2>/dev/null | head -1 || echo 'version unknown'))"
    PHASES_SKIPPED+=("Phase 8: GitHub CLI install")
  elif ! command -v brew &>/dev/null; then
    # Homebrew is required for GitHub CLI installation
    print_warn "Homebrew not found — cannot install GitHub CLI. This indicates Phase 7 may have failed."
    PHASES_SKIPPED+=("Phase 8: GitHub CLI (Homebrew not found)")
    return 0
  else
    print_step "Installing GitHub CLI..."
    brew install gh
    print_done "GitHub CLI installed"
    PHASES_COMPLETED+=("Phase 8: GitHub CLI install")
  fi

  gh_auth_login
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
        PHASES_SKIPPED+=("Phase 9: Watchman (Homebrew not found)")
      else
        local log_file="/tmp/watchman_install.log"
        print_step "Starting Watchman installation in the background..."
        brew install watchman >"$log_file" 2>&1 &
        disown
        print_done "Watchman installing in background — log: ${log_file}"
        echo ""
        print_warn "Watchman may need Full Disk Access to work properly."
        print_info "If you see permission errors, go to:"
        print_info "  System Settings → Privacy & Security → Full Disk Access"
        print_info "  and enable Watchman (or your terminal app)."
        PHASES_COMPLETED+=("Phase 9: Watchman (installing in background — log: ${log_file})")
      fi
    else
      print_info "Skipping Watchman installation"
      PHASES_SKIPPED+=("Phase 9: Watchman (declined)")
    fi
  fi
}

# =============================================================================
# POST-PHASE VERIFICATION
# =============================================================================

_verify_dev_environment() {
  print_step "Verifying dev environment setup with npx fs-webdev/checkSetup..."
  echo ""
  set +e
  npx fs-webdev/checkSetup
  local check_exit=$?
  set -e
  echo ""
  if ((check_exit == 0)); then
    print_done "Dev environment verification passed"
  else
    print_warn "Dev environment verification returned exit code ${check_exit} — you may need to revisit setup steps"
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

  echo -e "  ${YELLOW}${BOLD}⚠  Reload your shell to apply all changes:${RESET}"
  echo ""
  echo -e "  ${CYAN}source ~/.zshrc${RESET}"
  echo -e "    ${DIM}or restart your terminal${RESET}"
  echo ""

  echo -e "  ${BOLD}Next steps by role:${RESET}"
  echo ""
  echo -e "  ${BOLD}Designers:${RESET}"
  echo -e "    Clone the ux-playground repository and startup claude:"
  echo -e "      ${CYAN}git clone https://github.com/fs-webdev/ux-playground.git${RESET}"
  echo -e "      ${CYAN}cd ux-playground${RESET}"
  echo -e "      ${CYAN}claude${RESET}"
  echo -e "        ${DIM}ask claude to help you setup and start the project${RESET}"
  echo ""
  echo -e "  ${BOLD}Developers:${RESET}"
  echo -e "    Visit the Frontier docs for project-specific setup:"
  echo -e "      https://frontier.familysearch.org/docs"
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
  _verify_dev_environment
  print_summary
}

main "$@"
