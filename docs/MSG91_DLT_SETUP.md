# MSG91 + Jio DLT — Fix Error 400 (Template ID Missing)

Agar MSG91 **API Failed Logs** mein ye dikhe:

| Code | Description |
|------|-------------|
| **400** | Template ID Missing or Invalid Template |
| **311** | Same request twice within 10 seconds |

Balance recharge ke baad bhi ye **configuration** issue hai, credits nahi.

---

## 1. Do alag Template IDs

| ID type | Kahan se milega | `.env` variable |
|---------|-----------------|-----------------|
| **MSG91 OTP Template ID** | MSG91 panel → **OTP** → Templates | `MSG91_OTP_TEMPLATE_ID` |
| **DLT Content Template ID** | Jio DLT portal → Approved OTP template (numeric) | `MSG91_DLT_TE_ID` |

Galat ID (Flow / OneAPI template ko OTP API mein daalna) → Error **400**.

---

## 2. `.env` set karein

```env
MSG91_AUTH_KEY=your_key
MSG91_OTP_TEMPLATE_ID=69b4eb747cddc60644022572   # MSG91 Templates → Send_otp (Active)
MSG91_DLT_TE_ID=1207177332464287287              # Template popup → DLT Template ID
MSG91_ENTITY_ID=1201177134694833374              # PE-TM Chain → PE/Entity ID
MSG91_OTP_VARIABLE=var                           # Template uses ##var##
MSG91_SENDER_ID=MEATVO
MSG91_DELIVERY_MODE=otp
MSG91_SEND_SENDER_IN_BODY=true
SMS_MSG91_MAX_ATTEMPTS=1
```

Backend restart: `npm run dev`

---

## 3. MSG91 panel checks

1. **Sender ID `MEATVO`** → Entity ID se mapped ho (DLT PE ID)
2. OTP template content mein placeholder: `##OTP##` ya jo panel dikhaye
3. Template **approved** / active (archived nahi)

---

## 4. Error 311 (duplicate)

- App mein Send OTP ek baar dabayein (loading ke dauran dubara na dabayein)
- `SMS_MSG91_MAX_ATTEMPTS=1` rakhein (already default)

---

## 5. Verify

```powershell
cd backend
node test-otp-debug.js
```

MSG91 logs mein naya request **Delivered** hona chahiye, Failed nahi.

---

## Dev testing (SMS fail ho to bhi)

```env
OTP_LOG_TO_CONSOLE=true
```

App ko `devOTP` response se verify kar sakte ho jab tak DLT mapping fix ho rahi ho.
