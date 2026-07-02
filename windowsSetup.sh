#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# FamilySearch Frontier Onboarding Setup Script — Windows (Git Bash)
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│  $1${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────────────┘${RESET}"
}

print_done()   { echo -e "  ${GREEN}✔${RESET}  $1"; }
print_skip()   { echo -e "  ${DIM}↷  $1 (already done)${RESET}"; }
print_warn()   { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
print_info()   { echo -e "  ${CYAN}ℹ${RESET}  $1"; }
print_error()  { echo -e "  ${RED}✖${RESET}  $1"; }
print_prompt() { echo -en "  ${BOLD}▶${RESET}  $1"; }
print_step()   { echo -e "  ${DIM}→${RESET}  $1"; }

PHASES_COMPLETED=()
PHASES_SKIPPED=()

GIT_NAME=""
GIT_EMAIL=""

# =============================================================================
# GUARDS
# =============================================================================

check_windows_bash() {
  if [[ "$(uname -s)" != MINGW* ]] && [[ "$(uname -s)" != CYGWIN* ]] && [[ "$(uname -s)" != MSYS* ]]; then
    print_error "This script is for Windows (Git Bash / MSYS2) only."
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
  echo -e "${BOLD}${CYAN}║       FamilySearch Frontier Onboarding Setup — Windows              ║${RESET}"
  echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  This script will configure your Windows machine for Frontier development."
  echo -e "  Some steps require external actions (GitHub, Artifactory) and will"
  echo -e "  wait for you to complete them in a browser."
  echo ""
  echo -e "  ${DIM}You can re-run this script at any time — completed steps are skipped.${RESET}"
  echo ""
}

# =============================================================================
# PHASE 0: COLLECT INPUTS + PREFLIGHT PORTAL PERMISSIONS
# =============================================================================

collect_inputs() {
  print_header "Pre-flight: Collecting Configuration"

  local existing_name
  existing_name="$(git config --global user.name 2>/dev/null || true)"
  if [[ -n "$existing_name" ]]; then
    GIT_NAME="$existing_name"
    print_skip "git user.name already set to \"${existing_name}\""
  else
    print_prompt "Your full name (for git commits): "
    read -r GIT_NAME
    while [[ -z "$GIT_NAME" ]]; do
      print_warn "Name cannot be empty."
      print_prompt "Your full name: "
      read -r GIT_NAME
    done
  fi

  local existing_email
  existing_email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$existing_email" ]]; then
    GIT_EMAIL="$existing_email"
    print_skip "git user.email already set to \"${existing_email}\""
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

  echo ""
  echo -e "  ${BOLD}Before continuing, you need permissions from the Engineering Tools Portal.${RESET}"
  echo -e "  ${BOLD}Request both of the following at the same time so you only wait once.${RESET}"
  echo ""
  echo -e "  ${BOLD}1.${RESET} Go to ${CYAN}https://tools.fsdpt.org/portal/userManagement/requestAccess${RESET}"
  echo -e "  ${BOLD}2.${RESET} Request ${BOLD}GitHub${RESET} permissions:"
  echo -e "        • ${BOLD}Github - fs-webdev - Member${RESET}"
  echo -e "        • ${BOLD}Github - fs-eng - Member${RESET} (if you are a developer)"
  echo -e "  ${BOLD}3.${RESET} Request ${BOLD}Artifactory${RESET} permissions:"
  echo -e "        • ${BOLD}Artifactory - User${RESET}"
  echo -e "  ${BOLD}4.${RESET} Ask your manager to approve all requests"
  echo ""
  echo -e "  ${DIM}Requesting both now avoids waiting for manager approval twice.${RESET}"
  echo ""

  pause_for_external_action "Request both GitHub and Artifactory permissions in the portal, wait for manager approval, then press Enter" || true

  print_done "Portal permissions requested"
}

# =============================================================================
# PHASE 1: VERIFY GIT (already installed on Windows)
# =============================================================================

phase_1_git() {
  print_header "Phase 1: Git"

  if command -v git &>/dev/null; then
    print_skip "Git already installed ($(git --version))"
    PHASES_SKIPPED+=("Phase 1: Git")
  else
    echo ""
    print_info "Git is not installed. Download and install it from:"
    echo -e "  ${CYAN}https://git-scm.com/download/win${RESET}"
    echo ""
    pause_for_external_action "Install Git for Windows, then press Enter"
    if command -v git &>/dev/null; then
      print_done "Git installed"
      PHASES_COMPLETED+=("Phase 1: Git")
    else
      print_error "Git still not found. Please install it and re-run this script."
      exit 1
    fi
  fi
}

# =============================================================================
# PHASE 2: GITHUB ACCESS
# =============================================================================

phase_2_github_access() {
  print_header "Phase 2: GitHub Organization Access"

  echo ""
  echo -e "  ${BOLD}This phase requires actions in your browser:${RESET}"
  echo ""
  echo -e "  ${BOLD}1.${RESET} Create a GitHub account at ${CYAN}https://github.com${RESET} (if you don't have one)"
  echo -e "  ${BOLD}2.${RESET} Enable two-factor authentication (2FA) on your GitHub account"
  echo -e "  ${BOLD}3.${RESET} Accept the GitHub org invitation email once your manager has approved"
  echo ""
  echo -e "  ${DIM}GitHub org membership was requested during preflight. If not yet approved, wait before continuing.${RESET}"
  echo ""

  if ! pause_for_external_action "Complete GitHub setup (account, 2FA, accept invitation) then press Enter"; then
    print_warn "Skipping GitHub access — some later steps may fail without org membership"
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

  local existing_name
  existing_name="$(git config --global user.name 2>/dev/null || true)"
  if [[ -n "$existing_name" ]]; then
    print_skip "git user.name = \"${existing_name}\""
  else
    git config --global user.name "$GIT_NAME"
    print_done "git user.name set to \"${GIT_NAME}\""
  fi

  local existing_email
  existing_email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$existing_email" ]]; then
    print_skip "git user.email = \"${existing_email}\""
  else
    git config --global user.email "$GIT_EMAIL"
    print_done "git user.email set to \"${GIT_EMAIL}\""
  fi

  local existing_rewrite
  existing_rewrite="$(git config --global url."https://".insteadOf 2>/dev/null || true)"
  if [[ "$existing_rewrite" == "git://" ]]; then
    print_skip "git url rewrite already configured (git:// → https://)"
  else
    git config --global url."https://".insteadOf "git://"
    print_done "git url rewrite configured (git:// → https://)"
  fi

  print_info "GitHub authentication is handled by the GitHub CLI (gh) in a later phase — no"
  print_info "personal access token or ~/.netrc file is needed."

  print_done "Git configuration complete"
  PHASES_COMPLETED+=("Phase 3: Git Config")
}

# =============================================================================
# PHASE 4: NODE.JS (fnm on Windows — replaces nvm which doesn't support Windows)
# =============================================================================

phase_4_node() {
  print_header "Phase 4: Node.js"

  # Already on Node 24 — just verify
  if command -v node &>/dev/null; then
    local node_major
    node_major="$(node --version | sed 's/v//' | cut -d. -f1)"
    if [[ "$node_major" == "24" ]]; then
      print_skip "Node $(node --version) already installed"
      PHASES_SKIPPED+=("Phase 4: Node.js")
      return 0
    else
      print_warn "Node $(node --version) is installed but Node 24 is recommended."
      print_info "Consider upgrading via fnm: https://github.com/Schniz/fnm"
    fi
  else
    print_info "Node not found. Install Node 24 via fnm (recommended) or from https://nodejs.org"
    echo ""
    print_info "To install fnm on Windows:"
    echo -e "  ${CYAN}winget install Schniz.fnm${RESET}"
    echo -e "  Then restart your terminal and run: ${CYAN}fnm install 24 && fnm default 24${RESET}"
    echo ""
    pause_for_external_action "Install Node 24, then press Enter"
    if command -v node &>/dev/null; then
      print_done "Node $(node --version) is now available"
      PHASES_COMPLETED+=("Phase 4: Node.js")
    else
      print_error "Node still not found. Please install it and re-run this script."
      exit 1
    fi
  fi
}

# =============================================================================
# PHASE 5: ARTIFACTORY
# =============================================================================

phase_5_artifactory() {
  print_header "Phase 5: Artifactory npm Registry"

  local current_registry
  current_registry="$(npm config get registry 2>/dev/null || true)"
  if [[ "$current_registry" == *"familysearch.jfrog.io"* ]]; then
    print_skip "Artifactory registry already configured"
    PHASES_SKIPPED+=("Phase 5: Artifactory")
    return 0
  fi

  echo ""
  echo -e "  ${DIM}Artifactory access was requested during preflight. Wait for manager approval before continuing.${RESET}"
  echo ""

  npm config set registry "https://familysearch.jfrog.io/artifactory/api/npm/fs-npm-prod-virtual/"

  local configured_registry
  configured_registry="$(npm config get registry)"
  if [[ "$configured_registry" != *"familysearch.jfrog.io"* ]]; then
    print_error "Failed to set Artifactory registry. Current: ${configured_registry}"
    exit 1
  fi
  print_done "Artifactory registry configured"

  echo ""
  echo -e "  ${BOLD}npm login will open your browser for SAML SSO authentication.${RESET}"
  echo -e "  ${DIM}Complete the login in your browser, then return here.${RESET}"
  echo ""

  npm login

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

  if command -v fr &>/dev/null; then
    print_skip "fr CLI already installed ($(fr --version 2>/dev/null || echo 'version unknown'))"
    PHASES_SKIPPED+=("Phase 6: Frontier CLI")
  else
    print_step "Installing @fs/fr-cli globally..."
    npm i -g @fs/fr-cli
    print_done "@fs/fr-cli installed"
    PHASES_COMPLETED+=("Phase 6: Frontier CLI")
  fi
}

# =============================================================================
# PHASE 7: GITHUB CLI & AUTHENTICATION
# =============================================================================

# Authenticate git with GitHub using the gh CLI OAuth web flow.
# This replaces the old personal access token + ~/.netrc approach.
gh_auth_login() {
  if ! command -v gh &>/dev/null; then
    print_warn "gh CLI not available — cannot authenticate with GitHub."
    print_info "After installing gh and restarting your terminal, run 'gh auth login' manually."
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

phase_7_github_cli() {
  print_header "Phase 7: GitHub CLI (gh) & Authentication"

  if command -v gh &>/dev/null; then
    print_skip "GitHub CLI already installed ($(gh --version 2>/dev/null | head -1))"
    PHASES_SKIPPED+=("Phase 7: GitHub CLI install")
  elif command -v winget &>/dev/null; then
    print_step "Installing GitHub CLI via winget..."
    winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements --scope user
    # Reload PATH in current session
    export PATH="$PATH:/c/Program Files/GitHub CLI"
    if command -v gh &>/dev/null; then
      print_done "GitHub CLI installed ($(gh --version | head -1))"
      PHASES_COMPLETED+=("Phase 7: GitHub CLI install")
    else
      print_warn "GitHub CLI installed but 'gh' not yet on PATH — restart your terminal, then run 'gh auth login'."
      PHASES_COMPLETED+=("Phase 7: GitHub CLI (restart terminal, then run 'gh auth login')")
      return 0
    fi
  else
    print_warn "winget not available."
    print_info "Install GitHub CLI manually from: https://cli.github.com"
    pause_for_external_action "Install GitHub CLI, then press Enter" || true
  fi

  gh_auth_login
}

# =============================================================================
# POST-PHASE VERIFICATION
# =============================================================================

_verify_dev_environment() {
  print_step "Verifying dev environment with npx fs-webdev/checkSetup..."
  echo ""
  set +e
  npx fs-webdev/checkSetup
  local check_exit=$?
  set -e
  echo ""
  if ((check_exit == 0)); then
    print_done "Dev environment verification passed"
  else
    print_warn "Verification returned exit code ${check_exit} — you may need to revisit some steps"
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

  echo -e "  ${YELLOW}${BOLD}⚠  Restart your terminal to ensure all PATH changes take effect.${RESET}"
  echo ""
  echo -e "  ${BOLD}Next steps:${RESET}"
  echo ""
  echo -e "  ${BOLD}Designers:${RESET}"
  echo -e "    Clone the ux-playground repository and start Claude:"
  echo -e "      ${CYAN}git clone https://github.com/fs-webdev/ux-playground.git${RESET}"
  echo -e "      ${CYAN}cd ux-playground${RESET}"
  echo -e "      ${CYAN}claude${RESET}"
  echo -e "        ${DIM}ask Claude to help you set up and start the project${RESET}"
  echo ""
  echo -e "  ${BOLD}Developers:${RESET}"
  echo -e "    Visit the Frontier docs for project-specific setup:"
  echo -e "      ${CYAN}https://frontier.familysearch.org/docs${RESET}"
  echo ""

  print_prompt "Press [Enter] to close..."
  read -r
}

# =============================================================================
# MAIN
# =============================================================================

main() {
  check_windows_bash
  print_banner
  collect_inputs
  phase_1_git
  phase_2_github_access
  phase_3_git_config
  phase_4_node
  phase_5_artifactory
  phase_6_frontier_cli
  phase_7_github_cli
  _verify_dev_environment
  print_summary
}

main "$@"
