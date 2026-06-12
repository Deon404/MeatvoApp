/**
 * Update google-services.json with OAuth Client ID
 * Usage: node update_google_services.js YOUR_CLIENT_ID
 */

const fs = require('fs');
const path = require('path');

// Get Client ID from command line argument
const clientId = process.argv[2];

if (!clientId) {
  console.error('❌ Error: Client ID is required!');
  console.log('\n📝 Usage:');
  console.log('   node update_google_services.js YOUR_CLIENT_ID');
  console.log('\n📝 Example:');
  console.log('   node update_google_services.js 77877568608-abc123xyz.apps.googleusercontent.com');
  console.log('\n💡 Get Client ID from:');
  console.log('   https://console.cloud.google.com/apis/credentials?project=meatvo-8d161');
  process.exit(1);
}

// Validate Client ID format
if (!clientId.includes('.apps.googleusercontent.com')) {
  console.error('❌ Error: Invalid Client ID format!');
  console.log('   Expected format: 77877568608-xxxxx.apps.googleusercontent.com');
  process.exit(1);
}

const googleServicesPath = path.join(__dirname, 'android', 'app', 'google-services.json');

// Read current google-services.json
let googleServices;
try {
  googleServices = JSON.parse(fs.readFileSync(googleServicesPath, 'utf8'));
} catch (error) {
  console.error('❌ Error reading google-services.json:', error.message);
  process.exit(1);
}

// Update oauth_client
if (googleServices.client && googleServices.client[0]) {
  googleServices.client[0].oauth_client = [
    {
      client_id: clientId,
      client_type: 3
    }
  ];
  
  console.log('✅ Updating google-services.json...');
  console.log(`   Client ID: ${clientId}\n`);
  
  // Write updated file
  try {
    fs.writeFileSync(
      googleServicesPath,
      JSON.stringify(googleServices, null, 2),
      'utf8'
    );
    
    console.log('✅ Successfully updated google-services.json!');
    console.log('\n📝 Next steps:');
    console.log('   1. Verify the file: android/app/google-services.json');
    console.log('   2. Rebuild app: flutter clean && flutter pub get && flutter run');
    console.log('   3. Test OTP with your test number and PIN\n');
    
  } catch (error) {
    console.error('❌ Error writing google-services.json:', error.message);
    process.exit(1);
  }
} else {
  console.error('❌ Error: Invalid google-services.json structure!');
  process.exit(1);
}



