const ColabRobot = require('./colab-robot')

const DEFAULT_PORT = 4242

const argv = require('yargs')
    .usage('Usage: node start-vps.js -p [port] -c [cookie-name]')
    .alias('c', 'cookie_name')
    .alias('p', 'port')
    .alias('s', 'save_cookie_name')
    .alias('u', 'update_cookie')
    .default('p', DEFAULT_PORT)
    .describe('no_connect', 'Just load the cookie but doest get new VPS')
    .describe('s', 'Save the current cookie when closing')
    .describe('p', 'The port where the reverse SSH will atach')
    .describe('c', 'The cookie name file to load the session')
    .describe('u', 'Update the cookie if login is succesfull')
    .help('h')
    .argv

if (!argv.cookie_name && !argv.save_cookie_name &&  !argv.no_connect){
    console.error('Must provide a cookie name if connecting!')
    process.exit(1)
}

const robot = new ColabRobot()

if (argv.port)                  robot.setTargetPort(argv.port)
if (argv.cookie_name)           robot.setCookieName(argv.cookie_name)
if (argv.no_connect)            robot.setNoConnect()
if (argv.save_cookie_name)      robot.setSaveCookie(argv.save_cookie_name)
if (argv.update_cookie)         robot.setUpdateCookies()

robot.initialize()
.then(() => {
    robot.startRobot()
})