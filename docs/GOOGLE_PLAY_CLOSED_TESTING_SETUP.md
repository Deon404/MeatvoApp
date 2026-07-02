# Google Play Closed Testing Setup for Meatvo

Last checked: 2026-07-02

This document is for setting up **Meatvo** on Google Play for **closed testing** and finishing the setup items shown in your Play Console screenshot.

## 1. Current Meatvo app facts from this repo

- App name: `Meatvo`
- Play package name / application ID: `com.meatvo.app`
- Current Flutter version: `1.0.1+30`
- Current Android target SDK: `36`
- Release bundle output path: `frontend/build/app/outputs/bundle/release/app-release.aab`
- Support email already used in app/site: `support@meatvo.in`
- Privacy policy content already exists in:
  - `landing/index.html`
  - `docs/index.html`
- Android permissions currently present:
  - Internet
  - Precise location
  - Approximate location
  - Camera
  - Read media images / storage
  - Notifications

## 2. Important issues to fix before Play submission

Do these first, otherwise your store listing, privacy policy, and support details can become inconsistent.

1. **Use one public domain everywhere.**
   - This repo references both `meatvo.com` and `meatvo.in`.
   - Pick one live public domain for Play Console, privacy policy, support pages, and in-app links.

2. **Use one support phone number everywhere.**
   - App code currently uses `+91 80921 44650`.
   - Landing/privacy pages currently show `+91 91101 59550`.
   - Pick one number and make the app, website, and Play Console match.

3. **Make sure the privacy policy URL is public and live.**
   - Play Console needs an active URL, not just a local file.
   - Example format: `https://your-live-domain/privacy`
   - If you use an anchor page such as `https://your-live-domain/#privacy`, make sure it loads publicly without login.

4. **Prepare a real review login path.**
   - Meatvo uses OTP login.
   - You must give Google working sign-in instructions on the `App content > Sign-in details` page.

## 3. Closed testing rule you must know

If your Google Play developer account is a **personal account created after November 13, 2023**, Google currently requires:

- at least **12 testers**
- testers must stay **opted in continuously for 14 days**
- only after that can you apply for **production access**

If your account is older or is not a new personal account, the same closed-testing setup steps below still apply, but the production gate may differ.

## 4. Build the signed Android App Bundle

Do this from the repo root:

```powershell
cd C:\project\MeatvoApp\frontend
flutter pub get
flutter build appbundle --release --dart-define-from-file=env.production.json
```

Notes:

- This project already has `frontend/android/keystore.properties`, so the release build should use your configured upload key.
- The current bundle already exists at:
  - `C:\project\MeatvoApp\frontend\build\app\outputs\bundle\release\app-release.aab`
- If you are uploading a new build, increase the version in `frontend/pubspec.yaml` first.
  - Current version is `1.0.1+30`
  - For the next upload, use something like `1.0.2+31`

## 5. Create the Play Console app

In Play Console:

1. Open `Play Console`.
2. Click `Home > Create app`.
3. Default language: choose your main store language.
4. App name: `Meatvo`
5. App or game: choose `App`
6. Free or paid: choose based on your rollout plan
   - usually `Free` for delivery apps
7. Contact email: use `support@meatvo.in`
8. Accept:
   - Developer Program Policies
   - US export laws
   - Play App Signing terms
9. Click `Create app`.

## 6. Finish the screenshot tasks under App Content

Google does not let new personal-account apps start closed testing until the required setup is finished. Do these in this order.

### 6.1 Privacy policy

Path:

- `Policy and programs > App content > Privacy Policy`

Steps:

1. Click `Start`.
2. Paste the public privacy policy URL.
3. Save.

Recommended Meatvo value:

- Use your live public privacy policy URL based on the landing page content already in this repo.
- Do not submit until the URL is public and reachable without login.

### 6.2 Sign-in details

Path:

- `Policy and programs > App content > Sign-in details`

Steps:

1. Click `Start`.
2. Click `+ Add new instructions`.
3. Add working access details for Google review.
4. Save.

What Meatvo should provide:

- A valid test phone number
- Exact OTP access instructions
- Any special note if login depends on OTP timing, role selection, or region

Best practical option:

1. Create one dedicated review/test customer account.
2. Make sure its OTP flow works reliably.
3. In the instructions, explain the exact steps from app open to home screen.
4. If reviewer must use a fixed OTP or a test bypass account, state it clearly.

### 6.3 Ads

Path:

- `Policy and programs > App content > Ads`

Recommended Meatvo answer:

- `No`, unless you are actually showing ads in the app

Why:

- I did not find an ad SDK in the current mobile app dependencies.
- Payment offers and your own products do **not** automatically mean the app contains ads.

### 6.4 Content rating

Path:

- `Policy and programs > App content > Content rating`

Steps:

1. Click `Start`.
2. Fill the questionnaire honestly.
3. Submit and save the rating.

Recommended Meatvo direction:

- This should likely end up as a low-maturity commerce/service rating.
- Do **not** answer as if this is a kids app.
- Do **not** hide any real user interaction, chat, payments, or location behavior.

### 6.5 Target audience

Path:

- `Policy and programs > App content > Target audience`

Recommended Meatvo answer:

- Choose **18+ only** unless you intentionally want teen users included

Why:

- Meatvo is a location-based food commerce app with OTP login, payments, delivery tracking, and meat ordering.
- Including children age groups triggers stricter Families policy requirements.

### 6.6 Data safety

Path:

- `Policy and programs > App content > Data safety`

Steps:

1. Click `Start`.
2. Read the overview.
3. Fill the form based on the app's real behavior.
4. Save and submit.

Do **not** mark Meatvo as `No data collected`.

Based on the current codebase, you should review and likely declare collection/use of:

- Name
- Phone number
- Email, if used for accounts or support flows
- Delivery address
- Precise location
- Approximate location
- Order history / purchase activity
- Payment transaction references
- Push/notification token
- Photos or images for admin/rider upload flows

Based on the repo, these statements are also likely true and should be verified before you submit:

- `Data is encrypted in transit`
  - production mobile traffic is expected to use HTTPS
  - Android manifest has `usesCleartextTraffic="false"`
- `Users can request data deletion`
  - current privacy policy says users can request account deletion via `support@meatvo.in`

Important:

- Data safety must match both the app behavior and the privacy policy.
- If you are unsure about a category, review the mobile code, backend storage, and every SDK before submitting.

### 6.7 Government apps

Path:

- `Policy and programs > App content > Government apps`

Recommended Meatvo answer:

- `No`

### 6.8 Financial features

Path:

- `Policy and programs > App content > Financial features`

Recommended Meatvo answer:

- `No`

Why:

- Meatvo processes food orders and payments, but it is not a lending, banking, credit, investment, or insurance app.

### 6.9 Health

Path:

- `Policy and programs > App content > Health`

Recommended Meatvo answer:

- `No`

## 7. Finish store presence setup

These are the last two items shown in your screenshot.

### 7.1 Select app category and contact details

Path:

- `Grow users > Store presence > Store settings`

Steps:

1. Open `Store settings`.
2. In `App category`, choose:
   - Type: `App`
   - Category: `Food & Drink`
3. Add support contact details:
   - Email: `support@meatvo.in`
   - Website: your single live public domain
   - Phone: your single final support phone number
4. Add up to five relevant tags.
5. Save.

Suggested Meatvo tags:

- choose only the tags that are obviously relevant to delivery commerce and food ordering
- do not add vague or unrelated tags just for reach

### 7.2 Set up your store listing

Path:

- `Grow users > Store presence > Main store listing`

Fill these first:

- App name
- Short description
- Full description
- App icon
- Screenshots
- Feature graphic

Current Play requirements you should meet:

- App name: max `30` characters
- Short description: max `80` characters
- Full description: max `4000` characters
- App icon:
  - `512 x 512`
  - `PNG`
- Feature graphic:
  - `1024 x 500`
  - `JPEG` or `24-bit PNG`
- Screenshots:
  - minimum `2`
  - recommended at least `4` high-resolution phone screenshots

Meatvo store listing recommendation:

- Use final-looking screenshots from the customer flow:
  - OTP login
  - home/catalog
  - product detail
  - cart/checkout
  - live delivery tracking
- Avoid mockups with fake awards, `#1`, `Best`, or promotional spam text.

## 8. Start closed testing

You can only start closed testing after the mandatory setup is done.

Path:

- `Testing > Closed testing`

### 8.1 Add testers

1. Open `Testing > Closed testing`.
2. Click `Manage track`.
3. Open the `Testers` tab.
4. Add testers using either:
   - email lists, or
   - Google Groups
5. Add a tester feedback email or URL.
   - easiest option: `support@meatvo.in`
6. Copy the shareable opt-in link.
7. Save changes.

Recommended setup:

- Use a **Google Group** for easier management.
- Put at least **12 real Gmail accounts** in it if your developer account is a new personal account.
- Add more than 12 if possible, because some testers may not complete opt-in properly.

### 8.2 Create the closed test release

1. Stay on `Testing > Closed testing`.
2. Go to the release section for the track.
3. Create a new release if needed.
4. Upload:
   - `C:\project\MeatvoApp\frontend\build\app\outputs\bundle\release\app-release.aab`
5. Add release notes.
6. Review the release.
7. Start rollout to `Closed testing`.

Recommended release name / note:

- Release name: `1.0.1 (30) Closed Test 1`
- Release note: `Initial closed testing build for Meatvo`

### 8.3 Share the opt-in link

Important rules:

- The opt-in link appears only after the app is in a published test state, not draft.
- If you use Google Groups, users must join the group before opting in.
- First-time test links can take a few hours to become available.

Send testers:

1. the closed-test opt-in link
2. the device requirement: Android phone with Google Play
3. the test login instructions
4. exactly what you want them to test

## 9. What your testers should do

Tell every tester to:

1. Open the opt-in link.
2. Join the test.
3. Install Meatvo from Google Play.
4. Keep the app installed.
5. Sign in and use the app like a real customer.
6. Send feedback on:
   - OTP login
   - address/location
   - browsing
   - cart and checkout
   - COD and online payment flow
   - order tracking
   - notifications

If your account is a new personal account, make sure:

- at least **12 testers remain opted in**
- they stay opted in for **14 continuous days**

## 10. After 14 days: apply for production access

If Google requires production access for your account:

1. Go to `Dashboard`.
2. Click `Apply for production`.
3. Answer questions about:
   - your closed test
   - your app
   - production readiness
4. Summarize tester feedback and what you changed because of it.
5. Submit.

Keep notes during testing so this is easy later.

## 11. Meatvo-specific submission checklist

- [ ] One final public domain selected
- [ ] One final support phone selected
- [ ] Privacy policy URL public and live
- [ ] Sign-in details tested end-to-end
- [ ] `app-release.aab` built successfully
- [ ] App content declarations completed
- [ ] Store settings completed
- [ ] Store listing uploaded with icon, screenshots, feature graphic
- [ ] Closed test testers added
- [ ] Closed test rollout published
- [ ] Opt-in link shared
- [ ] Tester feedback being collected

## 12. Official sources used

- Create and set up your app:
  - https://support.google.com/googleplay/android-developer/answer/9859152
- Set up an open, closed, or internal test:
  - https://support.google.com/googleplay/android-developer/answer/9845334
- App testing requirements for new personal developer accounts:
  - https://support.google.com/googleplay/android-developer/answer/14151465
- Prepare your app for review:
  - https://support.google.com/googleplay/android-developer/answer/9859455
- Provide information for Google Play's Data safety section:
  - https://support.google.com/googleplay/android-developer/answer/10787469
- Add preview assets to showcase your app:
  - https://support.google.com/googleplay/android-developer/answer/9866151
- Choose a category and tags for your app or game:
  - https://support.google.com/googleplay/android-developer/answer/9859673
