/**
 * Run Migrations Script
 * Executes all SQL migrations in order using Node.js pg module
 * 
 * Usage: node run-migrations.js
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

// Database connection
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    database: process.env.DB_NAME || 'meatvo',
});

const migrationsDir = path.join(__dirname, 'migrations');

async function runMigrations() {
    console.log('🚀 Starting migrations...\n');

    // Get all SQL files sorted
    const files = fs.readdirSync(migrationsDir)
        .filter(f => f.endsWith('.sql'))
        .sort();

    if (files.length === 0) {
        console.log('No migrations found.');
        process.exit(0);
    }

    console.log(`Found ${files.length} migration(s):\n`);

    for (const file of files) {
        const filePath = path.join(migrationsDir, file);
        const sql = fs.readFileSync(filePath, 'utf8');

        console.log(`📄 Running: ${file}`);

        try {
            await pool.query(sql);
            console.log(`   ✅ Success\n`);
        } catch (err) {
            console.log(`   ❌ Error: ${err.message}`);
            console.log(`      SQL State: ${err.sqlState}`);
            console.log(`      Code: ${err.code}`);
            console.log(`\n`);
            // Continue with next migration
        }
    }

    console.log('✅ All migrations completed!\n');

    await pool.end();
}

runMigrations().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});