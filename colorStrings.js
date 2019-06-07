// https://en.wikipedia.org/wiki/ANSI_escape_code
const colors = { red: '\u001B[31m', green: '\u001B[32m', yellow: '\u001B[33m', reset: '\u001B[39m' }

const paint = (str, color) => {
  return `${colors[color]}${str}${colors.reset}`
}

const TIP = paint('Tip:', 'green')
const ERROR = paint('Error:', 'red')
const ISSUE = paint('Issue:', 'red')
const WARNING = paint('Warning:', 'yellow')

const SUCCESS_MESSAGE = paint('Congrats, your environment looks setup correctly', 'green')

module.exports = {
  TIP,
  ERROR,
  ISSUE,
  WARNING,
  SUCCESS_MESSAGE,
}
