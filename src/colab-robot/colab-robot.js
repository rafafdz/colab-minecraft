const puppeteer = require('puppeteer');
const PayloadGenerator = require('./payload-generator')
const PayloadServer = require('./payload-server')
const fs = require('fs').promises

const NEW_NOTEBOOK_URL = 'https://colab.research.google.com/#create=true'

class ColabRobot {
    
    // Just set the default valiues and leave other as options
    constructor(){
        this.robotEnabled = true
        this.updateCookies = false
        this.saveCookies = false
        this.loadCookies = false
        this.cookieName = null
        // A copy of the browser cookies object
        this.targetPort = null
        this.cookieIndex = null
        this.server = null
    }

    async initialize(){
        this.browser = await puppeteer.launch({
            headless: false
            // userDataDir: './user_data_test'
        })

        this.page = await this.browser.newPage()
        await this.page.setViewport({ width: 1280, height: 720 })

        if (this.loadCookies) await this.loadCookiesJson()

        this.intercept = true
        await this.setupConnectionListener()

        // Debugging!
        global.robot = this
        global.browser = this.browser
        global.page = this.page
    }

    setTargetPort(targetPort) {
        this.targetPort = targetPort
    }

    setCookieName(cookieName){
        this.loadCookies = true
        this.cookieName = cookieName
    }

    // Config option
    setNoConnect() {
        this.robotEnabled = false
    }

    setSaveCookie(cookieName) {
        this.saveCookies = true
        this.cookieName = cookieName
    }

    setUpdateCookies(){
        this.updateCookies = true
    }


    async close(statusCode=0){
        await this.page.close()
        await this.browser.close()
        if (this.server) this.server.close()
        process.exit(statusCode)
    }

    // Get all elements containing a given text
    async getElementsWithText(element, text) {
        return await this.page.$x(`//${element}[contains(text(), '${text}')]`);
    }
    
    // Checks if there are any elements of type 'element' with a given text
    async elementWithTextExists(element, text) {
        let elements = await this.getElementsWithText(element, text)
        return elements.length > 0
    }

    async takeScreenshot(error=false){
        let now = new Date();
        let dateStr = `${now.getDate()}-${now.getMonth() + 1}-${now.getFullYear()}`
        let hourStr = `${now.getHours()}-${now.getMinutes()}-${now.getSeconds()}`
        let path
        if (error){
            path = `./screenshots/error-${dateStr}_${hourStr}.png`
        } else {
            path = `./screenshots/${dateStr}_${hourStr}.png`
        }
        console.log(`Saving screenshot to ${path}`)
        await this.page.screenshot({ path, fullPage: true })
        // Avoid errors by waiting the screenshot to get saved
        await this.page.waitForTimeout(1000)
    }

    // Detects when the connection has been made by looking at requests
    async setupConnectionListener(){
        await this.page.setRequestInterception(true)
        this.page.on('request', async request => {
            if (this.intercept && request.url().includes('resources?authuser=0')) {
                // Do not call this function again
                this.intercept = false
                this.onConnectionReady(request.url())
            }
            request.continue()
        })
    }

    async saveCookiesJson(){
        let path = `../../cookies/${this.cookieName}`
        console.log(`Saving cookies to ${path}`)
        const cookies = await this.page.cookies()
        await fs.writeFile(path, JSON.stringify(cookies, null, 2))
    }

    async loadCookiesJson(){
        let path = `../../cookies/${this.cookieName}`
        console.log(`Loading cookies from ${this.cookieName}`)
        try  {
            const cookiesString = await fs.readFile(path)
            const cookies = JSON.parse(cookiesString)
            await this.page.setCookie(...cookies)
        }
        catch (error){
            console.error(`Error while reading cookies: ${error}`)
            await this.close(1)
        }
    }
    
    // Checks if RAM text is displayed in button
    async waitConnected() {
        const maxRetries = 30
        for (let i = 0; i < maxRetries; i++) {
            let found = await this.page.evaluate(() => {
                let root = document.querySelector('colab-connect-button').shadowRoot
                return root.innerHTML.includes("colab-usage-bar")
            })
            
            if (found) return

            if (await this.elementWithTextExists('h2', 'Too many sessions')) {
                throw 'ERROR: Session Limit Exceeded!'
            }

            await this.page.waitForTimeout(1000)
        }
        throw `Didnt find connected button after ${maxRetries} retries`
    }
    
    // Searches word by word if script was succesfullty typed
    async checkCommandTyped(command) {
        let found_count = 0
        let words = command.split(' ')
        for (let word of words) {
            let found = await this.elementWithTextExists('span', word)
            found_count += found
        }
        
        let ratio = found_count / words.length
        // Return true if more than 40% of words found
        return ratio > 0.4
    }

    // Called when a server has been succesfully assigned to the notebook
    async onConnectionReady(keepAliveUrl){
        // Get cookies for keepalive Job
        let cookies = await this.page.cookies()
        
        let generator = await new PayloadGenerator(this.targetPort, 
                                                   keepAliveUrl, 
                                                   cookies)
        await generator.generate('./payload.zip')
        
        this.server = new PayloadServer(this.onFileSent.bind(this), 
                                        this.onServerError.bind(this),
                                        './payload.zip')
        
        let fileUrl = await this.server.startServer()

        console.log(`Url generated: ${fileUrl}`)
        let command = `!curl -s ${fileUrl} -o out.zip && unzip out.zip && ` +
                      `chmod +x init.sh && ./init.sh`
        
        const retries = 5
        for (let i = 0; i < retries; i++) {
            await this.typeCommand(command)
            
            if (await this.checkCommandTyped(command)) {
                console.log('Script typed Succesfully!')
                await this.executeCommand()
                return
            }
            
            console.error('Script not detected, retrying!')
        }
        
        console.error(`Could not type script after ${retries} retries. Exiting`)
        await this.close(1)
    }
    
    // Called by the server when somenone has downloaded the file
    async onFileSent(){
        console.log("File sent! Exiting with success!")
        await this.close()
    }
    
    async onServerError(){
        return
    }
    
    async typeCommand(command){
        await this.page.click('div.inputarea')
        await this.page.waitForTimeout(500)
        await this.page.type('div.inputarea', command, { delay: 3 })
    }
    
    async executeCommand(){
        await this.page.click('div.cell-execution-container')
    }

    async startRobot(){
        await this.page.goto(NEW_NOTEBOOK_URL)
        // await this.page.waitForNavigation({ waitUntil: 'load' })
        // console.log('Dom loaded')

        if (await this.elementWithTextExists('h2', 'Google sign-in required')){
            console.error('WARNING! Session has not started')
            await this.takeScreenshot(true)
            if (this.robotEnabled) await this.close(1)

            console.log('Waiting manual login!')
            await this.page.waitForSelector('div.inputarea', { timeout: 1000000 })
        }

        for (let retry = 0; retry < 3; retry++){
            try {
                await this.page.waitForSelector('div.inputarea')
                console.log('Session started Succesfully')
                if (this.saveCookies || this.updateCookies) await this.saveCookiesJson()
                break
            }
            catch (error) {
                if (retry < 2){
                    console.error(`Error while waiting inputarea. Reloading : ${error}`)
                    await this.page.goto(NEW_NOTEBOOK_URL)
                    continue
                }
                console.error(`Error while starting session: ${error}`)
                await this.takeScreenshot(true)
                if (this.robotEnabled) await this.close(1)
            }
        }

        
        
        if (!this.robotEnabled){
            console.log('Starting in no-connect mode')
            return
        }
            
        try {
            console.log('Page loaded. Connecting')
            await this.page.click('colab-connect-button')
            await this.waitConnected()
        }
        catch (error) {
            console.log(`Could not connect: ${error}`)
            await this.takeScreenshot(true)
            await this.close(1)
        }
    }
}

module.exports = ColabRobot