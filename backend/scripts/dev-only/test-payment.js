const axios = require('axios');

async function testPayment() {
  try {
    const authResponse = await axios.post('http://localhost:8082/api/auth/send-otp', {
      phone: '+919555555560',
    });

    const otp = authResponse.data.data.devOTP;
    const verifyResponse = await axios.post('http://localhost:8082/api/auth/verify-otp', {
      phone: '+919555555560',
      otp,
    });

    const token = verifyResponse.data.data.accessToken;

    const paymentResponse = await axios.post(
      'http://localhost:8082/api/payments/phonepe/initiate',
      { orderId: 1 },
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    const ok = paymentResponse.status >= 200 && paymentResponse.status < 300;
    console.log(ok ? 'PASSED payment initiate' : 'FAILED payment initiate', 'HTTP', paymentResponse.status);
    if (!ok) process.exit(1);
  } catch (error) {
    console.error('FAILED —', error.response?.data?.message || error.message);
    process.exit(1);
  }
}

testPayment();
