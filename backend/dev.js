// Local development entry — force development mode before .env is loaded.
// Production on VPS uses: NODE_ENV=production node index.js (or PM2).
process.env.NODE_ENV = 'development';
require('./index.js');
