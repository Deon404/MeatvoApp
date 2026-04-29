const axios = require('axios');

async function testPayment() {
  try {
    // First get a token
    const authResponse = await axios.post('http://localhost:8082/api/auth/send-otp', {
      phone: '+919555555560'
    });
    
    const otp = authResponse.data.data.devOTP;
    
    const verifyResponse = await axios.post('http://localhost:8082/api/auth/verify-otp', {
      phone: '+919555555560',
      otp: otp
    });
    
    const token = verifyResponse.data.data.accessToken;
    
    // Test payment initiation
    console.log('Sending payment request with orderId: 1');
    const paymentResponse = await axios.post('http://localhost:8082/api/payments/phonepe/initiate', 
      { orderId: 1 },
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      }
    );
    
    console.log('Payment Response:', JSON.stringify(paymentResponse.data, null, 2));
    console.log('Validation Issues:', JSON.stringify(paymentResponse.data.data?.issues || [], null, 2));
    
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
    if (error.response?.data?.data?.issues) {
      error.response.data.data.issues.forEach((issue, i) => {
        console.error(`Issue ${i + 1}:`, issue);
      });
    }
  }
}

testPayment();
