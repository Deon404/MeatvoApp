# PhonePe Payment Integration

> **See also:** [Checkout Pipeline Architecture](./checkout-pipeline-architecture.md) — full end-to-end checkout flow including cart, slots, atomic order creation, and how payment fits into the pipeline.

## Overview

Secure PhonePe payment integration for Node.js backend with PostgreSQL database.

## Features

### 🔐 Security

- **Checksum Verification**: SHA256-based signature validation
- **Amount Validation**: Prevents payment amount manipulation
- **Webhook Authentication**: Verifies PhonePe webhook signatures
- **Duplicate Prevention**: Handles duplicate webhook calls

### 📊 Payment Flow

1. **Initiation**: Create payment request and get payment URL
2. **Redirect**: User redirected to PhonePe payment page
3. **Webhook**: PhonePe sends payment confirmation
4. **Status Check**: Manual status verification option

### 🛡️ Fraud Prevention

- Order amount validation against webhook amount
- Transaction ID tracking
- Payment status consistency checks
- Timeout handling

## API Endpoints

### Initiate Payment

```http
POST /api/payments/phonepe/initiate
Authorization: Bearer <token>
Content-Type: application/json

{
  "orderId": 123
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "paymentId": 456,
    "paymentUrl": "https://api.phonepe.com/pay/...",
    "transactionId": "TXN_123_1640995200000",
    "amount": 299.00
  },
  "message": "Payment initiated successfully"
}
```

### Check Payment Status

```http
GET /api/payments/:orderId/status
Authorization: Bearer <token>
```

**Response:**

```json
{
  "success": true,
  "data": {
    "paymentId": 456,
    "orderId": 123,
    "status": "SUCCESS",
    "gatewayTransactionId": "TXN_123_1640995200000",
    "amount": 299.00,
    "orderStatus": "CONFIRMED",
    "gatewayResponse": {...},
    "createdAt": "2024-01-01T12:00:00Z"
  },
  "message": "Payment status retrieved"
}
```

### PhonePe Webhook

```http
POST /api/payments/phonepe/webhook
X-VERIFY: <checksum>
Content-Type: application/json

{
  "code": "PAYMENT_SUCCESS",
  "data": {
    "merchantTransactionId": "TXN_123_1640995200000",
    "transactionId": "T240101000001234",
    "amount": 29900,
    "state": "COMPLETED",
    "responseCode": "SUCCESS"
  }
}
```

## Database Schema

### Payment Transactions Table

```sql
CREATE TABLE payment_transactions (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
  status VARCHAR(50) NOT NULL DEFAULT 'INITIATED' 
    CHECK (status IN ('INITIATED', 'PENDING', 'SUCCESS', 'FAILED', 'REFUNDED')),
  gateway VARCHAR(50) NOT NULL DEFAULT 'PHONEPE',
  gateway_transaction_id TEXT,
  payment_url TEXT,
  gateway_response JSONB,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Orders Table Addition

```sql
ALTER TABLE orders ADD COLUMN payment_status VARCHAR(50) 
  DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED'));
```

## Payment States

### Transaction Status

- **INITIATED**: Payment request created
- **PENDING**: User redirected to payment page
- **SUCCESS**: Payment completed successfully
- **FAILED**: Payment failed
- **REFUNDED**: Payment refunded

### Order Status Updates

- **PLACED** → **CONFIRMED** (when payment successful)
- **payment_status**: **PENDING** → **PAID**

## Environment Variables

```bash
# PhonePe Configuration
PHONEPE_API_BASE=https://api.phonepe.com/v1
PHONEPE_MERCHANT_ID=your_merchant_id
PHONEPE_SALT_KEY=your_salt_key
PHONEPE_SALT_INDEX=1

# URLs
PHONEPE_REDIRECT_URL=http://localhost:3000/payment/return
PHONEPE_WEBHOOK_URL=http://localhost:8080/api/payments/phonepe/webhook
```

## Security Measures

### 1. Checksum Verification

```javascript
const generateChecksum = (payload) => {
  const stringToHash = payload + PHONEPE_SALT_KEY;
  return crypto.createHash('sha256').update(stringToHash).digest('hex') + '###' + PHONEPE_SALT_INDEX;
};
```

### 2. Amount Validation

```javascript
// Verify webhook amount matches order amount
const expectedAmount = payment.amount * 100; // Convert to paise
if (webhookAmount !== expectedAmount) {
  // Reject webhook
}
```

### 3. Webhook Signature

```javascript
const verifyWebhookSignature = (payload, signature) => {
  const expectedChecksum = generateChecksum(payload);
  return signature === expectedChecksum;
};
```

## Error Handling

### Payment Initiation Errors

- **Order not found**: 404
- **Invalid order status**: 400
- **Payment already initiated**: 400
- **PhonePe API error**: 500

### Webhook Errors

- **Missing signature**: 400
- **Invalid signature**: 401
- **Amount mismatch**: 400
- **Unknown transaction**: 200 (idempotent)

## Testing

### Development Mode

Use test credentials and amounts:

```javascript
// Test amounts (in paise)
const testAmounts = [100, 200, 500]; // ₹1, ₹2, ₹5
```

### Webhook Testing

```bash
# Test webhook locally
curl -X POST http://localhost:8080/api/payments/phonepe/webhook \
  -H "Content-Type: application/json" \
  -H "X-VERIFY: test_checksum" \
  -d '{"code":"PAYMENT_SUCCESS","data":{...}}'
```

## Integration Steps

### 1. Database Setup

```bash
# Run migration
psql -d meatvo -f migrations/002_create_payment_tables.sql
```

### 2. Environment Configuration

```bash
# Set environment variables
export PHONEPE_MERCHANT_ID="your_merchant_id"
export PHONEPE_SALT_KEY="your_salt_key"
export PHONEPE_REDIRECT_URL="https://yourdomain.com/payment/return"
export PHONEPE_WEBHOOK_URL="https://yourdomain.com/api/payments/phonepe/webhook"
```

### 3. Frontend Integration

```javascript
// Initiate payment
const response = await fetch('/api/payments/phonepe/initiate', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ orderId: 123 })
});

const { paymentUrl } = response.data;
window.location.href = paymentUrl;
```

## Monitoring & Logging

### Payment Events

- Payment initiation
- Payment success/failure
- Webhook processing
- Amount mismatches
- Duplicate webhooks

### Metrics to Track

- Payment success rate
- Average payment time
- Webhook response time
- Error rates by type

## Troubleshooting

### Common Issues

1. **Checksum Mismatch**
  - Verify salt key and index
  - Check payload encoding
2. **Amount Mismatch**
  - Ensure paise conversion
  - Check decimal handling
3. **Webhook Not Received**
  - Verify webhook URL accessibility
  - Check PhonePe dashboard configuration
4. **Payment Status Stuck**
  - Implement status polling
  - Check timeout handling

### Debug Mode

```javascript
// Enable debug logging
localStorage.setItem('payment_debug', 'true');
```

## Production Considerations

1. **HTTPS Required**: All endpoints must use HTTPS
2. **Rate Limiting**: Implement payment initiation limits
3. **Monitoring**: Set up alerts for payment failures
4. **Backup**: Implement manual payment verification
5. **Compliance**: Follow PCI DSS guidelines

## Support

### PhonePe Documentation

- [PhonePe Developer Portal](https://developer.phonepe.com/)
- [Payment Gateway Integration](https://developer.phonepe.com/v1/docs/payment-gateway)

### Error Codes

- **BAD_REQUEST**: Invalid request parameters
- **AUTHORIZATION_FAILED**: Invalid credentials
- **INTERNAL_SERVER_ERROR**: PhonePe server error
- **TIMEOUT**: Request timeout

This implementation provides a secure, production-ready PhonePe payment integration with comprehensive error handling and fraud prevention measures.