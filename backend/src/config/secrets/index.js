const configLoader = require('./configLoader');
const secretManager = require('./secretManager');

// Export the main configuration loader
module.exports = {
  config: configLoader,
  secrets: secretManager,
  
  // Convenience method to get configuration
  async getConfig() {
    return await configLoader.load();
  },
  
  // Convenience method to get a specific config value
  async get(key) {
    return configLoader.get(key);
  }
};
