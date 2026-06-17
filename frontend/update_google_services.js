/**
 * Update google-services.json with OAuth Client ID
 * Usage: node update_google_services.js YOUR_CLIENT_ID
 */

const fs = require('fs');
const path = require('path');

const clientId = process.argv[2];

if (!clientId) {
  console.error('Usage: node update_google_services.js YOUR_CLIENT_ID');
  process.exit(1);
}

if (!clientId.includes('.apps.googleusercontent.com')) {
  console.error('Invalid Client ID format (expected *.apps.googleusercontent.com)');
  process.exit(1);
}

const googleServicesPath = path.join(__dirname, 'android', 'app', 'google-services.json');

let googleServices;
try {
  googleServices = JSON.parse(fs.readFileSync(googleServicesPath, 'utf8'));
} catch (error) {
  console.error('Error reading google-services.json:', error.message);
  process.exit(1);
}

if (googleServices.client && googleServices.client[0]) {
  googleServices.client[0].oauth_client = [{ client_id: clientId, client_type: 3 }];

  try {
    fs.writeFileSync(googleServicesPath, JSON.stringify(googleServices, null, 2), 'utf8');
    console.log('PASSED — updated google-services.json');
  } catch (error) {
    console.error('FAILED —', error.message);
    process.exit(1);
  }
} else {
  console.error('FAILED — invalid google-services.json structure');
  process.exit(1);
}
