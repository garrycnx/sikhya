export async function sendOtpSms(mobile: string, otp: string): Promise<void> {
  if (process.env.NODE_ENV !== 'production') {
    console.log('\n=============================');
    console.log(`DEV OTP for ${mobile} -> ${otp}`);
    console.log('=============================\n');
    return;
  }

  const apiKey = process.env.FAST2SMS_API_KEY;
  if (!apiKey) throw new Error('FAST2SMS_API_KEY not set');

  // Fast2SMS expects 10-digit Indian number (strip +91 or 91 prefix)
  const number = mobile.replace(/^\+?91/, '').replace(/\D/g, '');

  const res = await fetch('https://www.fast2sms.com/dev/otp/send', {
    method: 'POST',
    headers: {
      'authorization': apiKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      variables_values: otp,
      route:            'otp',
      numbers:          number,
    }),
  });

  const data = await res.json() as { return: boolean; message?: string[] };
  if (!data.return) {
    throw new Error(`Fast2SMS error: ${data.message?.join(', ') ?? 'unknown'}`);
  }
}
