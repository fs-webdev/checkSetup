#!/usr/bin/env node

const fs = require('fs')
const os = require('os')
const path = require('path')
const axios = require('axios')
const netrc = require('netrc')()
const { execSync } = require('child_process')

const { TIP, ERROR, ISSUE, WARNING, SUCCESS_MESSAGE } = require('./colorStrings')

const [, , privateRepo] = process.argv
const rawDataGitHubUrl = `https://raw.githubusercontent.com/fs-webdev/${privateRepo || 'zion'}/master/package.json`

const MINIMUM_RECOMMENDED_NODE_VERSION = 14
const MINIMUM_RECOMMENDED_NPM_VERSION = 6

const artifactoryUrl = '@fs:registry=https://familysearch.jfrog.io/artifactory/api/npm/fs-npm-prod-virtual/'

performAllChecks()

async function performAllChecks() {
  let errorMessage = ''
  errorMessage += checkNodeVersion()
  errorMessage += checkNpmVersion()
  errorMessage += checkNvmVersion()
  errorMessage += checkArtifactoryAccess()
  errorMessage += await checkNetrcConfig()

  if (errorMessage === '') {
    console.log('\n', SUCCESS_MESSAGE)
  } else {
    console.log(errorMessage)
  }
}

function checkArtifactoryAccess() {
  const artifactoryErrorMessage = `${ISSUE}
      Unable to access a module published to artifactory.
      Follow the instructions here for more info https://www.familysearch.org/frontier/docs/getting-started/setup#setting-up-artifactory`

  console.log('Checking ~/.npmrc file and npm access for @fs scoped modules')
  try {
    const npmrcFile = fs.readFileSync(path.join(os.homedir(), '.npmrc'), 'utf8')
    if (!npmrcFile.includes(artifactoryUrl)) {
      return `\n${ISSUE}
      Your npmrc file needs to be setup with the FamilySearch artifactory instance.\n${artifactoryErrorMessage}`
    }

    const checkMySetupOutput = execSync('npx @fs/check-my-setup --npm-check', { encoding: 'utf8' })
    if (!checkMySetupOutput.includes('is working great!')) {
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
  if (!process.execPath.includes('/.nvm/')) {
    return `${TIP}
    We highly recommend using nvm to install and switch between versions of node. More info here https://github.com/creationix/nvm`
  }
  console.log('Using nvm, good work\n')
  return ''
}

async function checkNetrcConfig() {
  console.log('Checking ~/.netrc file and github access to fs-webdev')
  if (Object.keys(netrc).length === 0) {
    return `${ISSUE}
    You don't appear to have a ~/.netrc file. In order to install private github dependencies, it is
    necessary to have a correct entry in your ~/.netrc file.`
  }
  const githubData = netrc['github.com']
  if (githubData === undefined) {
    return `${ISSUE}
    You don't appear to have a github.com entry in your ~/.netrc file. In order to install private github dependencies, it is
    necessary to have a correct github.com entry in your ~/.netrc file.`
  }

  try {
    const data = await axios.get(rawDataGitHubUrl, {
      headers: {
        Authorization: `token ${githubData.login}`,
        Accept: 'application/vnd.github.v3+json',
      },
    })
    if (data.status !== 200) {
      return `${WARNING}
      A call to a private repo on github.com/fs-webdev did not return a status of 200. Your ~/.netrc file may not be setup correctly`
    }

    if (netrc['api.github.com'] === undefined) {
      console.log(`${TIP} if you ever want to use curl or similar terminal commands to hit github's API, you can add an entry into your ~/.netrc file
      that has the same data as your github.com entry, but change the machine name to "api.github.com". Then you won't have to worry about
      setting authentication headers or tokens in curl`)
    }
  } catch (err) {
    return `${ERROR}
    An error occurred when trying to get data from a private repo on github.com. Check the following error message, and contact frontier core if necessary;
    ${err.message}`
  }
  console.log('~/.netrc file appears valid\n')
  return ''
}

function checkNpmVersion() {
  console.log('Checking npm version')
  const command = 'npm --version'
  try {
    const npmVersion = execSync(command, { encoding: 'utf8' })
    console.log('npm version: ', npmVersion)
    const [major, minor] = npmVersion.split('.').map(Number)
    if (major < MINIMUM_RECOMMENDED_NPM_VERSION) {
      return `${ISSUE} You are using npm version ${major}, but ${MINIMUM_RECOMMENDED_NPM_VERSION} is the minimum version we support`
    }
    if (major === 6 && minor === 9) {
      return `${ISSUE}
      There is a known bug with npm v6.9. You need to run 'npm i -g npm@6.14'`
    }
  } catch (err) {
    return `${ERROR}
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
    return `${ISSUE}
    You are using node version ${major}, but ${MINIMUM_RECOMMENDED_NODE_VERSION} is the minimum version we support`
  }
  console.log('node version: ', nodeVersion, '\n')
  return ''
}
