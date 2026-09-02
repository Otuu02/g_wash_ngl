const nodemailer = require('nodemailer');

module.exports = async function handler(req, res) {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed. Use POST.' });
  }

  try {
    const { to, recipient, subject, html, htmlBody, text, bodyText, fromName } = req.body || {};
    const targetEmail = to || recipient;
    const emailSubject = subject || 'Notification from G-Wash NG';
    const emailHtml = html || htmlBody || text || bodyText || '<p>No content</p>';
    const emailText = text || bodyText || emailHtml.replace(/<[^>]*>?/gm, '');

    if (!targetEmail) {
      return res.status(400).json({ error: 'Target email recipient is required.' });
    }

    const gmailUser = process.env.GMAIL_USER || 'gwashng@gmail.com';
    const gmailAppPassword = process.env.GMAIL_APP_PASSWORD || 'xonspumasgtmnlqx';

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailUser,
        pass: gmailAppPassword,
      },
    });

    const mailOptions = {
      from: `"${fromName || 'G-Wash NG'}" <${gmailUser}>`,
      to: targetEmail,
      subject: emailSubject,
      text: emailText,
      html: emailHtml,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log('✅ Email dispatched successfully:', info.messageId, 'to:', targetEmail);

    return res.status(200).json({
      success: true,
      messageId: info.messageId,
      recipient: targetEmail,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('❌ Error sending email via SMTP:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Failed to dispatch email.',
    });
  }
};
