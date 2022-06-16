const http = require('http')
const crypto = require('crypto')
const fs = require('fs')
const { loadConfig } = require('./utils')

class PayloadServer {

    constructor(callBackSucess, callBackError, filePath) {
        this.callBackSucess = callBackSucess
        this.callBackError = callBackError
        this.filePath = filePath
        this.server = null
    }

    close(){
        if (this.server) this.server.close()
    }

    generateRandomRoute() {
        this.randomRoute = crypto.randomBytes(10).toString('hex')
    }

    async startServer() {
        this.generateRandomRoute()
        this.server = http.createServer(this.serverCallback.bind(this))


        const params =  loadConfig()

        const webIp   = params.server_domain
        const webPort = params.web_server_port
        
        try {
            await this._startServerPromise(webIp, webPort)
            return `http://${webIp}:${webPort}/${this.randomRoute}`
        }
        catch (error) {
            console.error(`Error while listening: ${error}`)
            throw `Could not listen at port ${port}`
        }        
    }


    _startServerPromise(ip, port){
        const serverPromise = new Promise(((resolve, reject) => {
            this.server.listen(port, '0.0.0.0', () => {
                console.log(`Server is running on http://${ip}:${port}`)
                resolve()
            })
            this.server.once('error', err => {
                reject(err)
            })

        }).bind(this))
        return serverPromise
    }

    serverCallback(req, res) {
        if (!this.randomRoute ) {
            throw 'Cannot start server if random url is not generated'
        }

        if (req.url == '/' + this.randomRoute) {
            // Add variable definition on top
            console.log(`Sending file! to ${req.connection.remoteAddress}`)
            
            fs.readFile(this.filePath, (error, content) =>  {

                if (error){
                    res.writeHead(500)
                    res.end(`Server Error -> ${error}`)
                    this.callBackError()
                    return
                }
                res.setHeader("Content-Type", "application/zip")
                res.writeHead(200)
                // Set the script as body
                res.end(content)
                this.callBackSucess()
            })

        } else {
            console.log(`Wrong route requested: ${req.url}`)
            res.writeHead(500)
            res.end(err)
            this.callBackError()
        }
    }
}

module.exports = PayloadServer