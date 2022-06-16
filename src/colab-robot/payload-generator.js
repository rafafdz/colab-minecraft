const fs = require('fs')
const ncp = require('ncp').ncp;
const archiver = require('archiver');
const { loadConfig } = require('./utils');

const SCRIPT_FILENAME = './work/init.sh'


function copyRecursive(source, dest){
    return new Promise((resolve, reject) => {
        ncp(source, dest, err => {
            if (err) {
                reject(err)
                return
            }
            resolve()
        })
    })
}


function createZipSync(sourceDir, dest){
    let zipPromise = new Promise((resolve, reject) => {
        let archive = archiver('zip');
        let output = fs.createWriteStream(dest);
        archive.pipe(output);
        archive.directory(sourceDir, false);
        archive.finalize();

        output.on('close', () => {
            // Resolve giving the bytes written
            resolve(archive.pointer())
        });

        archive.on('error', err => {
            reject(err)
        });
    })
    return zipPromise
}

// Generates a custom zip that contains scripts and files needed
// to create a reverse connnection from colab computer to a remote server
class PayloadGenerator {

    constructor(targetPort, keepAliveUrl, cookies) {
        this.targetPort = targetPort
        this.keepAliveUrl = keepAliveUrl
        this.cookies = cookies
    }

    async generate(outputFile) {
        await this._copyPayloadToWork()
        this._modifyMainScript()
        // delete old ouput folder and create new one
        await createZipSync('./work', outputFile)
    }

    // Generates a String with the cookies to be used in cURL
    _generateCookieString() {
        let mapped = this.cookies.map(cookie => `${cookie.name}=${cookie.value}`)
        return mapped.join(';') + ';'
    }


    async _copyPayloadToWork(){
        // Delete
        fs.rmdirSync('./work', { recursive: true })
        await copyRecursive('./payload', './work')
        await copyRecursive('../../ssh-keys/', './work/')
    }

    _modifyMainScript(){
        let cookieStr = this._generateCookieString()

        const params = loadConfig()
        // Transform the JSON parameters in variables for the shell script
        let joinedParams = Object.keys(params).map(key => `${key}="${params[key]}"`)
                            .join('\n')

        // Modify the script by appending custom info on top
        let firstLine = joinedParams + '\n' +  
            `target_port="${this.targetPort}"\n` +
            `connect_url="${this.keepAliveUrl}"\n` +
            `cookies="${cookieStr}"`

        let rawScript
        try {
            rawScript = fs.readFileSync(SCRIPT_FILENAME, 'utf8')
        }
        catch (error) {
            console.error(`An error occoured while reading script: ${error}`)
            process.exit(1)
        }

        let newContent = firstLine + '\n' + rawScript
        fs.writeFileSync(SCRIPT_FILENAME, newContent, 'utf-8')
    }

}


module.exports = PayloadGenerator