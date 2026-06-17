const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const files = [
  'frontend/lib/screens/profile/profile_screen.dart',
  'frontend/lib/screens/rider/rider_order_detail_screen.dart',
  'frontend/lib/screens/rider/rider_dashboard_screen.dart',
  'frontend/lib/services/admin_service.dart',
  'frontend/lib/models/delivery_slot_model.dart',
];

for (const rel of files) {
  const gitPath = rel.replace(/^frontend\//, 'old_meatvo/');
  try {
    const content = execSync(`git show HEAD:"${gitPath}"`, {
      encoding: 'utf8',
      cwd: REPO,
    });
    const abs = path.join(REPO, rel);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, content, 'utf8');
    console.log('OK', rel);
  } catch (e) {
    console.log('FAIL', rel, e.message);
  }
}
