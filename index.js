#!/usr/bin/env node

const fs = require('fs')
const os = require('os')
const path = require('path')
const { execSync } = require('child_process')

const { TIP, ERROR, ISSUE, SUCCESS_MESSAGE } = require('./colorStrings')

const [, , privateRepo = 'zion'] = process.argv

const MINIMUM_RECOMMENDED_NODE_VERSION = 24
const MINIMUM_RECOMMENDED_NPM_VERSION = 11

const artifactoryRegistry = 'https://familysearch.jfrog.io/artifactory/api/npm/fs-npm-prod-virtual/'
const isMacOS = process.platform === 'darwin'

performAllChecks()

async function performAllChecks() {
  let errorMessage = ''
  errorMessage += checkNodeVersion()
  errorMessage += checkNpmVersion()
  errorMessage += checkNvmVersion()
  errorMessage += checkArtifactoryAccess()
  errorMessage += await checkGitHubAccess()
  errorMessage += checkHomebrew()
  errorMessage += checkGitHubCli()

  if (errorMessage === '') {
    console.log('\n', SUCCESS_MESSAGE)
  } else {
    console.log(errorMessage)
  }
}

function checkArtifactoryAccess() {
  const artifactoryErrorMessage = `${ISSUE}
      Unable to access npm modules through artifactory.
      Follow the instructions here for more info https://www.familysearch.org/frontier/docs/getting-started/setup#setting-up-artifactory`

  console.log('Checking npm access through the Artifactory registry')
  try {
    const registry = execSync('npm config get registry', { encoding: 'utf8' }).trim().replace(/\/$/, '')
    const normalizedArtifactoryRegistry = artifactoryRegistry.replace(/\/$/, '')
    if (registry !== normalizedArtifactoryRegistry) {
      return `\n${ISSUE}
      Your npm default registry must be set to the FamilySearch artifactory instance.\n${artifactoryErrorMessage}`
    }

    const scopedAccessCheckOutput = execSync('npx @fs/check-my-setup --npm-check', { encoding: 'utf8' })
    if (!scopedAccessCheckOutput.includes('is working great!')) {
      return artifactoryErrorMessage
    }

    const npmAccessCheckOutput = execSync(`npm view axios version --registry=${artifactoryRegistry}`, {
      encoding: 'utf8',
    })
    if (!npmAccessCheckOutput.trim()) {
      return artifactoryErrorMessage
    }
  } catch (err) {
    return artifactoryErrorMessage
  }
  console.log(`Access to artifactory works well\n`)
  return ''
}

function checkNvmVersion() {
  console.log('Checking for nvm usage')
  try {
    execSync('fnm --version', { encoding: 'utf8' })
    console.log('Using fnm, good work\n')
    return ''
  } catch (_) {}
  if (!process.execPath.includes('/.nvm/')) {
    return `\n${TIP}
    We highly recommend using nvm to install and switch between versions of node. More info here https://github.com/creationix/nvm`
  }
  console.log('Using nvm, good work\n')
  return ''
}

async function checkGitHubAccess() {
  console.log('Checking github access to fs-webdev')

  try {
    execSync(`git ls-remote https://github.com/fs-webdev/${privateRepo}.git HEAD`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    })
  } catch (err) {
    // If git ls-remote fails, diagnose which credential sources are available
    let diagnostics = []

    // Check .netrc
    const netrcPath = path.join(os.homedir(), '.netrc')
    if (fs.existsSync(netrcPath)) {
      try {
        const netrcContent = fs.readFileSync(netrcPath, 'utf8')
        if (netrcContent.includes('github.com')) {
          diagnostics.push('- .netrc file exists with github.com entry')
        } else {
          diagnostics.push('- .netrc file exists but missing github.com entry')
        }
      } catch (_) {
        diagnostics.push('- .netrc file exists but cannot be read')
      }
    } else {
      diagnostics.push('- .netrc file not found')
    }

    // Check git credential
    try {
      const credentialOutput = execSync('git credential fill', {
        encoding: 'utf8',
        input: 'host=github.com\nprotocol=https\n',
        stdio: ['pipe', 'pipe', 'pipe']
      })
      if (credentialOutput.includes('password=')) {
        diagnostics.push('- git credential helper has github.com credentials')
      } else {
        diagnostics.push('- git credential helper found but no credentials')
      }
    } catch (_) {
      diagnostics.push('- git credential helper not available or no credentials')
    }

    return `\n${ERROR}
    Unable to access private GitHub repository "fs-webdev/${privateRepo}".

    Current credential sources:
    ${diagnostics.join('\n    ')}

    To fix this:
    1. Generate a GitHub personal access token: https://github.com/settings/tokens
    2. Add it to macOS keychain: security add-internet-password -s github.com -a <username> -w <token>
    OR
    3. Add it to ~/.netrc:
       machine github.com
       login <username>
       password <token>
       chmod 600 ~/.netrc

    Git will automatically use whichever credential source is available.`
  }
  console.log('GitHub access works\n')
  return ''
}

function checkNpmVersion() {
  console.log('Checking npm version')
  const command = 'npm --version'
  try {
    const npmVersion = execSync(command, { encoding: 'utf8' })
    console.log('npm version: ', npmVersion)
    const [major] = npmVersion.split('.').map(Number)
    if (major < MINIMUM_RECOMMENDED_NPM_VERSION) {
      return `\n${ISSUE}
    You are using npm version ${major}, but ${MINIMUM_RECOMMENDED_NPM_VERSION} is the minimum version we support\n`
    }
  } catch (err) {
    return `\n${ERROR}
    There was an issue trying to check your version of npm. Try running "npm --version" in your terminal.
    Please reach out to a member of the frontier core team for assistance`
  }
  return ''
}

function checkNodeVersion() {
  console.log('Checking node version')
  const { node: nodeVersion } = process.versions
  const [major] = nodeVersion.split('.')
  if (Number(major) < MINIMUM_RECOMMENDED_NODE_VERSION) {
    return `\n${ISSUE}
    You are using node version ${major}, but ${MINIMUM_RECOMMENDED_NODE_VERSION} is the minimum version we support\n`
  }
  console.log('node version: ', nodeVersion, '\n')
  return ''
}

function checkHomebrew() {
  if (!isMacOS) {
    console.log('Skipping homebrew check (macOS only)\n')
    return ''
  }

  console.log('Checking for homebrew')
  const command = 'brew --version'
  try {
    const brewVersion = execSync(command, { encoding: 'utf8' })
    console.log('homebrew version: ', brewVersion, '\n')
  } catch (err) {
    return `\n${ISSUE}
    Homebrew is required for managing packages on Mac. You can install it by running: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
  }
  return ''
}

function checkGitHubCli() {
  if (!isMacOS) {
    console.log('Skipping GitHub CLI check (macOS only)\n')
    return ''
  }

  console.log('Checking for GitHub CLI')
  const command = 'gh --version'
  try {
    const ghVersion = execSync(command, { encoding: 'utf8' })
    console.log('GitHub CLI version: ', ghVersion, '\n')
  } catch (err) {
    return `\n${ISSUE}
    GitHub CLI is required to interact with GitHub from your terminal. You can install it with homebrew using "brew install gh"`
  }
  return ''
}
