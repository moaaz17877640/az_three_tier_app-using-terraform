// Read DB config from environment variables with safe defaults.
// This lets Terraform or the VM provisioning set the actual credentials instead
// of hardcoding them in source code.
module.exports = Object.freeze({
    DB_HOST: process.env.DB_HOST || 'localhost',
    DB_PORT: process.env.DB_PORT || 3306,
    DB_USER: process.env.DB_USER || 'root',
    DB_PWD: process.env.DB_PWD || '',
    DB_DATABASE: process.env.DB_DATABASE || 'exampledb'
});