const fs = require('fs');
const path = require('path');

const loadConfig = () => {
    const filepath = path.resolve(__dirname, '../../config/config.json')
    const data = fs.readFileSync(filepath, 'utf8')
    return JSON.parse(data)
}


module.exports = {
    loadConfig
}