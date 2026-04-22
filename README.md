# checkFrontierSetup

A tool to check if a developer's machine is set up correctly with the tooling and access needed for FamilySearch Frontier development. Also includes `macSetup.sh`, an interactive onboarding script that automates the full setup process for new developers.

---

## macSetup.sh — New User Onboarding (Mac)

`macSetup.sh` is an interactive, idempotent setup script for macOS. It walks a new user through every step needed to be productive on Frontier if using a Mac. **Re-running the script is safe** — completed steps are automatically detected and skipped.

### Running the script

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fs-webdev/checkSetup/master/macSetup.sh)
```

Alternatively, download and inspect before running:

```bash
curl -fsSL https://raw.githubusercontent.com/fs-webdev/checkSetup/master/macSetup.sh -o macSetup.sh
bash macSetup.sh
```

### What the script does

Walks through setting up Xcode CLT, GitHub org access, git config, nvm + Node 24, Artifactory npm registry, the Frontier CLI (`@fs/fr-cli`), and optional tools like Homebrew and Watchman. Some steps require browser actions (GitHub, Artifactory) and will pause so you can complete them. macOS only.

### After the script finishes

Run `source ~/.zshrc` (or open a new terminal) to apply all shell changes.

---

## windowsSetup.sh — New User Onboarding (Windows)

`windowsSetup.sh` is an interactive, idempotent setup script for Windows (Git Bash / MSYS2). It walks a new user through every step needed to be productive on Frontier if using a PC. **Re-running the script is safe** — completed steps are automatically detected and skipped.

### Running the script

In Git Bash:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fs-webdev/checkSetup/master/windowsSetup.sh)
```

Alternatively, download and inspect before running:

```bash
curl -fsSL https://raw.githubusercontent.com/fs-webdev/checkSetup/master/windowsSetup.sh -o windowsSetup.sh
bash windowsSetup.sh
```

### What the script does

Walks through verifying Git installation, GitHub org access, git config, Node 24 (via fnm), Artifactory npm registry, the Frontier CLI (`@fs/fr-cli`), and GitHub CLI (`gh`). Some steps require browser actions (GitHub, Artifactory) and will pause so you can complete them. Windows only.

### After the script finishes

Restart your terminal to ensure all PATH changes take effect.

---

## checkSetup — Environment Verification Tool

Checks that your machine has valid versions of Node and npm, that you're using nvm, and that `~/.netrc` and `~/.npmrc` are configured correctly (by making a test call to Artifactory and to a private `fs-webdev` GitHub repo).

You'll get a green success message if everything is in order, or red error messages for any problems.

### Usage

```bash
npx fs-webdev/checkSetup
```

### Contractors

Supply a private repo name to check against an org-specific repo instead of the default:

```bash
npx fs-webdev/checkSetup lightyear-react
```

---

## Maintainer Warning

**This package must not depend on any private GitHub repos or `@fs` Artifactory modules.** It is run during onboarding before those credentials are fully configured, so any such dependency will cause it to fail for the developers it's meant to help.
