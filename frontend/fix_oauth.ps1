# Firebase OAuth Client Auto-Fix Script for Windows
# This script helps you fix the empty oauth_client issue

Write-Host "🔧 Firebase OAuth Client Auto-Fix Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$PROJECT_ID = "meatvo-8d161"
$PACKAGE_NAME = "com.meatvo.app"
$SHA1 = "00:C1:5A:95:9B:BE:B0:45:2E:38:C3:0C:45:B1:72:B1:EE:18:44:87"

Write-Host "📋 Your Configuration:" -ForegroundColor Yellow
Write-Host "   Project ID: $PROJECT_ID"
Write-Host "   Package Name: $PACKAGE_NAME"
Write-Host "   SHA-1: $SHA1"
Write-Host ""

Write-Host "📝 Step-by-Step Instructions:" -ForegroundColor Green
Write-Host ""
Write-Host "1. Open Google Cloud Console:" -ForegroundColor White
Write-Host "   https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Configure OAuth Consent Screen (if first time):" -ForegroundColor White
Write-Host "   - Click 'OAuth consent screen' in left sidebar"
Write-Host "   - Select 'External' → Click 'Create'"
Write-Host "   - Fill: App name, email"
Write-Host "   - Click 'Save and Continue'"
Write-Host ""
Write-Host "3. Create OAuth Client ID:" -ForegroundColor White
Write-Host "   - Click '+ CREATE CREDENTIALS' → 'OAuth client ID'"
Write-Host "   - Application type: Android"
Write-Host "   - Name: Meatvo Android Debug"
Write-Host "   - Package name: $PACKAGE_NAME"
Write-Host "   - SHA-1: $SHA1"
Write-Host "   - Click 'Create'"
Write-Host "   - COPY the Client ID"
Write-Host ""
Write-Host "4. Update google-services.json:" -ForegroundColor White
Write-Host "   Run: node update_google_services.js YOUR_CLIENT_ID"
Write-Host ""

$clientId = Read-Host "Enter your Client ID (or press Enter to skip)"

if ($clientId -and $clientId -ne "") {
    Write-Host ""
    Write-Host "🔄 Updating google-services.json..." -ForegroundColor Yellow
    
    # Read current file
    $filePath = "android\app\google-services.json"
    
    if (Test-Path $filePath) {
        try {
            $content = Get-Content $filePath -Raw | ConvertFrom-Json
            
            # Update oauth_client
            if ($content.client -and $content.client[0]) {
                $content.client[0].oauth_client = @(
                    @{
                        client_id = $clientId
                        client_type = 3
                    }
                )
                
                # Write updated file
                $content | ConvertTo-Json -Depth 10 | Set-Content $filePath -Encoding UTF8
                
                Write-Host "✅ Successfully updated google-services.json!" -ForegroundColor Green
                Write-Host ""
                Write-Host "📝 Next steps:" -ForegroundColor Yellow
                Write-Host "   1. Rebuild app: flutter clean && flutter pub get && flutter run"
                Write-Host "   2. Test OTP with your test number and PIN"
            }
            else {
                Write-Host "❌ Error: Invalid google-services.json structure!" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "❌ Error: Failed to update file - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "❌ Error: google-services.json not found at $filePath" -ForegroundColor Red
        Write-Host "   Please make sure you're running this script from the project root directory" -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    Write-Host "💡 To update manually:" -ForegroundColor Yellow
    Write-Host "   1. Open: android\app\google-services.json"
    Write-Host "   2. Find line 15: `"oauth_client\": [],"
    Write-Host "   3. Replace with:"
    Write-Host "      `"oauth_client\": ["
    Write-Host "        {"
    Write-Host "          `"client_id\": `"YOUR_CLIENT_ID.apps.googleusercontent.com`","
    Write-Host "          `"client_type\": 3"
    Write-Host "        }"
    Write-Host "      ]"
    Write-Host ""
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

