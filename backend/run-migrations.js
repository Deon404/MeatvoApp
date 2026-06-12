/**
 * Run Migrations Script
 * Executes all SQL migrations in order using Node.js pg module
 * 
 * Usage: node run-migrations.js
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const { logger } = require('./src/utils/logger');

// Database connection
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'meatvo',
});

const migrationsDir = path.join(__dirname, 'migrations');

async function runMigrations() {
    logger.info('Starting migrations...');

    // Get all SQL files sorted
    const files = fs.readdirSync(migrationsDir)
        .filter(f => f.endsWith('.sql'))
        .sort();

    if (files.length === 0) {
        logger.info('No migrations found.');
        process.exit(0);
    }

    logger.info(`Found ${files.length} migration(s).`);

    for (const file of files) {
        const filePath = path.join(migrationsDir, file);
        const sql = fs.readFileSync(filePath, 'utf8');

        logger.info(`Running migration: ${file}`);

        try {
            await pool.query(sql);
            logger.info(`Migration succeeded: ${file}`);
        } catch (err) {
            logger.error(`Migration failed: ${file} - ${err.message}`);
            logger.error(`Migration SQL State: ${err.sqlState}`);
            logger.error(`Migration Code: ${err.code}`);
            // Continue with next migration
        }
    }

    logger.info('All migrations completed.');

    await pool.end();
}

runMigrations().catch(err => {
    logger.error(`Fatal error: ${err.message}`);
    process.exit(1);
});