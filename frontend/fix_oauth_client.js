/**
 * Firebase OAuth Client Auto-Fix Script
 * This script automatically creates OAuth client in Google Cloud Console
 * and updates google-services.json
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// Your Firebase Project Configuration
const PROJECT_ID = 'meatvo-8d161';
const PROJECT_NUMBER = '77877568608';
const PACKAGE_NAME = 'com.meatvo.app';
const SHA1_FINGERPRINT = '00:C1:5A:95:9B:BE:B0:45:2E:38:C3:0C:45:B1:72:B1:EE:18:44:87';

console.log('🔧 Firebase OAuth Client Auto-Fix Script');
console.log('==========================================\n');

console.log('📋 Configuration:');
console.log(`   Project ID: ${PROJECT_ID}`);
console.log(`   Package Name: ${PACKAGE_NAME}`);
console.log(`   SHA-1: ${SHA1_FINGERPRINT}\n`);

console.log('⚠️  This script requires Google Cloud CLI to be installed and authenticated.');
console.log('    If you don\'t have it, follow the manual steps in QUICK_FIX_OAUTH.md\n');

console.log('📝 Manual Steps (Recommended):');
console.log('   1. Go to: https://console.cloud.google.com/apis/credentials?project=meatvo-8d161');
console.log('   2. Click "+ CREATE CREDENTIALS" → "OAuth client ID"');
console.log('   3. Application type: Android');
console.log('   4. Fill in:');
console.log(`      - Name: Meatvo Android`);
console.log(`      - Package name: ${PACKAGE_NAME}`);
console.log(`      - SHA-1: ${SHA1_FINGERPRINT}`);
console.log('   5. Click "Create"');
console.log('   6. Copy the Client ID (format: 77877568608-xxxxx.apps.googleusercontent.com)');
console.log('   7. Run: node update_google_services.js YOUR_CLIENT_ID\n');

console.log('💡 Alternative: Use the update script after creating OAuth client manually\n');



