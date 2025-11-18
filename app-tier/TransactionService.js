const dbcreds = require('./DbConfig');
const sql = require('mssql');

// Connection config for Microsoft SQL Server (Azure SQL)
const poolConfig = {
    user: dbcreds.DB_USER,
    password: dbcreds.DB_PWD,
    server: dbcreds.DB_HOST,
    port: parseInt(dbcreds.DB_PORT, 10) || 1433,
    database: dbcreds.DB_DATABASE,
    options: {
        encrypt: true,
        enableArithAbort: true
    },
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};

let poolPromise = null;
async function ensurePool(){
    if (!poolPromise) {
        poolPromise = sql.connect(poolConfig);
    }
    return poolPromise;
}

async function addTransaction(amount, desc, callback){
    try{
        const pool = await ensurePool();
        const result = await pool.request()
            .input('amount', sql.Float, amount)
            .input('description', sql.NVarChar(255), desc)
            .query('INSERT INTO dbo.transactions (amount, description) OUTPUT INSERTED.id VALUES (@amount, @description)');
        const insertedId = result.recordset && result.recordset[0] && result.recordset[0].id;
        console.log('Added transaction id:', insertedId);
        if (callback) callback({ insertId: insertedId });
    }catch(err){
        console.error('addTransaction error:', err.message || err);
        if (callback) callback({success: false, error: err.message});
    }
}

async function getAllTransactions(callback){
    try{
        const pool = await ensurePool();
        const result = await pool.request().query('SELECT id, amount, description FROM dbo.transactions ORDER BY id');
        if (callback) callback(result.recordset);
    }catch(err){
        console.error('getAllTransactions error:', err.message || err);
        if (callback) callback([]);
    }
}

async function findTransactionById(id, callback){
    try{
        const pool = await ensurePool();
        const result = await pool.request().input('id', sql.Int, id).query('SELECT id, amount, description FROM dbo.transactions WHERE id = @id');
        if (callback) callback(result.recordset);
    }catch(err){
        console.error('findTransactionById error:', err.message || err);
        if (callback) callback([]);
    }
}

async function deleteAllTransactions(callback){
    try{
        const pool = await ensurePool();
        await pool.request().query('DELETE FROM dbo.transactions');
        if (callback) callback({success: true});
    }catch(err){
        console.error('deleteAllTransactions error:', err.message || err);
        if (callback) callback({success: false, error: err.message});
    }
}

async function deleteTransactionById(id, callback){
    try{
        const pool = await ensurePool();
        await pool.request().input('id', sql.Int, id).query('DELETE FROM dbo.transactions WHERE id = @id');
        if (callback) callback({success: true});
    }catch(err){
        console.error('deleteTransactionById error:', err.message || err);
        if (callback) callback({success: false, error: err.message});
    }
}

module.exports = {
    addTransaction,
    getAllTransactions,
    findTransactionById,
    deleteAllTransactions,
    deleteTransactionById
};







