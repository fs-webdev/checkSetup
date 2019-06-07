# checkFrontierSetup
A little tool to check if a person's computer is setup as expected with tooling and access they need.

## Usage
Run the following command
```bash
npx fs-webdev/checkFrontierSetup
```

This script will go through and verify that you have valid versions of node and npm, 
that you're using nvm, and that you have .netrc and .npmrc files that are setup correctly. 
(This is done by making a call to artifactory and to a private fs-webdev github repo)

You should get a Green Success message if all is well, or some Red Issues for any problems that occur

## MAINTAINER WARNING:
### In order for this command to be useful, we can't have any dependencies on private github repos, or @fs artifactory modules
