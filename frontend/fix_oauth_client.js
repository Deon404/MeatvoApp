/**
 * Firebase OAuth Client setup helper (dev only).
 * Manual steps: Google Cloud Console → Credentials → OAuth client ID (Android).
 * Then: node frontend/update_google_services.js YOUR_CLIENT_ID
 */

const PACKAGE_NAME = 'com.meatvo.app';
const PROJECT_ID = 'meatvo-8d161';

console.log('Firebase OAuth setup');
console.log(`Project: ${PROJECT_ID}  Package: ${PACKAGE_NAME}`);
console.log(`Console: https://console.cloud.google.com/apis/credentials?project=${PROJECT_ID}`);
console.log('Create Android OAuth client, then run: node update_google_services.js YOUR_CLIENT_ID');
