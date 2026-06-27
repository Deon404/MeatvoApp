#!/usr/bin/env node
/**
 * Starts the backend, waits for readiness, runs backend-smoke-check.js, then exits.
 * Used by GitHub Actions (npm run test:ci).
 */
const { spawn } = require('child_process');
const path = require('path');

const backendRoot = path.join(__dirname, '..');
const BASE_URL = process.env.BACKEND_TEST_BASE_URL || 'http://127.0.0.1:8080';
const SERVER_START_TIMEOUT_MS = Number(process.env.CI_SERVER_START_TIMEOUT_MS || 90000);
const POLL_INTERVAL_MS = 1000;

const serverEnv = {
  CASHFREE_API_BASE: 'https://sandbox.cashfree.com/pg',
  REDIS_ENCRYPTION_KEY: process.env.REDIS_ENCRYPTION_KEY || 'ci_redis_encryption_key_0123456789abcdef',
  ...process.env,
};

async function waitForHealth() {
  const deadline = Date.now() + SERVER_START_TIMEOUT_MS;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(`${BASE_URL}/api/auth/health`);
      const json = await response.json().catch(() => ({}));
      const status = String(json.status || '').toUpperCase();
      if (response.ok && status === 'OK' && json.db === 'connected') {
        return;
      }
    } catch (_) {
      // Server still starting
    }
    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
  }

  throw new Error(`Server did not become healthy within ${SERVER_START_TIMEOUT_MS}ms`);
}

function runNodeScript(scriptName, extraEnv = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', [scriptName], {
      cwd: backendRoot,
      env: { ...process.env, ...extraEnv },
      stdio: 'inherit',
    });

    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${scriptName} exited with code ${code}`));
    });
  });
}

async function run() {
  let serverLog = '';
  const server = spawn('node', ['index.js'], {
    cwd: backendRoot,
    env: serverEnv,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  server.stdout.on('data', (chunk) => {
    serverLog += chunk.toString();
  });
  server.stderr.on('data', (chunk) => {
    serverLog += chunk.toString();
  });

  const stopServer = () => {
    if (!server.killed) {
      server.kill('SIGTERM');
    }
  };

  process.on('SIGINT', () => {
    stopServer();
    process.exit(1);
  });
  process.on('SIGTERM', () => {
    stopServer();
    process.exit(1);
  });

  try {
    await waitForHealth();
    await runNodeScript('backend-smoke-check.js', { BACKEND_TEST_BASE_URL: BASE_URL });
  } catch (error) {
    console.error(`CI smoke test failed: ${error.message}`);
    if (serverLog) {
      console.error('--- server log (tail) ---');
      console.error(serverLog.slice(-8000));
    }
    process.exitCode = 1;
  } finally {
    stopServer();
    await new Promise((resolve) => {
      server.once('close', resolve);
      setTimeout(resolve, 5000);
    });
  }
}

run();
