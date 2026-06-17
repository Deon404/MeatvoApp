#!/usr/bin/env node
/**
 * Pre-deploy production readiness check.
 * Usage: NODE_ENV=production node scripts/production-check.js
 * Or:    npm run production:check
 */
require('dotenv').config();

const fs = require('fs');
const path = require('path');
const { validateProductionSecurity, validateSecretsAlways } = require('../src/config/validateEnv');

const backendRoot = path.join(__dirname, '..');
const errors = [];
const warnings = [];

function check(name, ok, message) {
  if (!ok) errors.push(`${name}: ${message}`);
}

function warn(name, message) {
  warnings.push(`${name}: ${message}`);
}

function fileExists(relativePath) {
  return fs.existsSync(path.join(backendRoot, relativePath));
}

console.log('Meatvo backend — production readiness check\n');

if (process.env.NODE_ENV !== 'production') {
  warn('NODE_ENV', 'Not set to production — re-run with NODE_ENV=production for full validation');
}

// Required deploy artifacts
check('ecosystem.config.js', fileExists('ecosystem.config.js'), 'PM2 config missing');
check('index.js', fileExists('index.js'), 'Entry point missing');
check('.env.vps.example', fileExists('.env.vps.example'), 'VPS env template missing');

// SECURITY env — always validate secrets; full production rules when NODE_ENV=production
const secretErrors = validateSecretsAlways();
for (const err of secretErrors) {
  errors.push(`env: ${err}`);
}

if (process.env.NODE_ENV === 'production') {
  const securityErrors = validateProductionSecurity();
  for (const err of securityErrors) {
    errors.push(`env: ${err}`);
  }
} else {
  console.log('Skipping production-only env rules (NODE_ENV != production)\n');
}

// Recommended production settings
if (!process.env.REDIS_URL) {
  errors.push('env: REDIS_URL is required in production');
}

if (String(process.env.TRUST_PROXY || '').toLowerCase() !== 'true') {
  warn('TRUST_PROXY', 'Should be true behind Nginx reverse proxy');
}

if (!process.env.CORS_ORIGINS || process.env.CORS_ORIGINS.split(',').every((o) => !o.trim())) {
  warn('CORS_ORIGINS', 'Set to your Flutter/web app HTTPS origin(s)');
}

// Report
if (warnings.length) {
  console.log('Warnings:');
  for (const w of warnings) console.log(`  ⚠  ${w}`);
  console.log('');
}

if (errors.length) {
  console.error('FAILED — fix before deploying:\n');
  for (const e of errors) console.error(`  ✗  ${e}`);
  console.error('\nCopy backend/.env.vps.example → .env and fill all secrets.');
  console.error('Generate secrets: openssl rand -hex 32');
  process.exit(1);
}

console.log('PASSED — backend env and deploy artifacts look ready for VPS.');
console.log('\nNext steps:');
console.log('  1. bash scripts/vps-phase1-setup.sh   (on VPS as root)');
console.log('  2. bash scripts/vps-phase2-deploy.sh  (deploy app + PM2)');
console.log('  3. bash scripts/vps-phase3-ssl.sh       (Let\'s Encrypt HTTPS)');
console.log('  4. npm run smoke                        (health + API smoke test)');
