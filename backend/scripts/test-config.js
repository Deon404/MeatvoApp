const constants = require('../src/config/env.constants');
const configLoader = require('../src/config/secrets/configLoader');

console.log('ENV_KEYS loaded:', Object.keys(constants.ENV_KEYS).length);
console.log('DEFAULTS loaded:', Object.keys(constants.DEFAULTS).length);
console.log('REQUIRED_ALWAYS:', constants.REQUIRED_ALWAYS.length, 'keys');

// Test no circular by requiring all in sequence
const validateEnv = require('../src/config/validateEnv');
console.log('validateEnv loaded: OK');

const { HEALTH_STATUS } = require('../src/constants/health.constants');
console.log('HEALTH_STATUS values:', Object.values(HEALTH_STATUS));

console.log('\n✅ All modules loaded without circular dependency errors');
