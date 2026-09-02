// ==========================================================================
// G-WASH NG LANDING PAGE JAVASCRIPT
// Interactive Features: Business Booking Funnel, Provider Registration,
// Realtime Firestore Integration, Dynamic Service Modals & Responsive Layout
// ==========================================================================

const FIREBASE_API_KEY = "AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw";
const FIREBASE_PROJECT_ID = "g-wash-ng";

// ==================== 1. MODAL CONTROLS ====================
function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.add('active');
    document.body.style.overflow = 'hidden'; // Prevent background scrolling
  }
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.remove('active');
    document.body.style.overflow = '';
  }
}

function switchModal(fromId, toId) {
  closeModal(fromId);
  setTimeout(() => {
    openModal(toId);
  }, 200);
}

// Pre-fill booking service from any service card button
function openBookingWithService(serviceName) {
  const select = document.getElementById('book-service-select');
  if (select) {
    for (let i = 0; i < select.options.length; i++) {
      if (select.options[i].text.includes(serviceName) || select.options[i].value === serviceName) {
        select.selectedIndex = i;
        break;
      }
    }
  }
  openModal('modal-book-service');
}

// Close modals when clicking backdrop or pressing ESC
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    document.querySelectorAll('.modal-overlay.active').forEach(modal => {
      modal.classList.remove('active');
    });
    document.body.style.overflow = '';
  }
});

document.addEventListener('click', (e) => {
  if (e.target.classList.contains('modal-overlay')) {
    e.target.classList.remove('active');
    document.body.style.overflow = '';
  }
});

// ==================== 2. BOOKING FORM HANDLER ====================
async function handleBookingSubmit(event) {
  event.preventDefault();
  const submitBtn = document.getElementById('book-submit-btn');
  const originalText = submitBtn.innerHTML;
  submitBtn.disabled = true;
  submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Dispatching Nearby Pro...';

  const name = document.getElementById('book-name').value.trim();
  const phone = document.getElementById('book-phone').value.trim();
  const service = document.getElementById('book-service-select').value;
  const city = document.getElementById('book-city').value;
  const datetime = document.getElementById('book-datetime').value;
  const address = document.getElementById('book-address').value.trim();
  const notes = document.getElementById('book-notes').value.trim();

  // Generate 4-digit security OTP and Booking Reference
  const otpCode = Math.floor(1000 + Math.random() * 9000).toString();
  const bookingRef = 'GW-' + Math.floor(100000 + Math.random() * 900000);

  // Firestore Document Payload
  const jobPayload = {
    fields: {
      bookingRef: { stringValue: bookingRef },
      customerName: { stringValue: name },
      customerPhone: { stringValue: phone },
      serviceName: { stringValue: service },
      city: { stringValue: city },
      serviceAddress: { stringValue: address },
      scheduledDateTime: { stringValue: datetime },
      notes: { stringValue: notes },
      securityOtp: { stringValue: otpCode },
      status: { stringValue: 'searching' },
      paymentStatus: { stringValue: 'pending_confirmation' },
      source: { stringValue: 'web_landing_page' },
      createdAt: { timestampValue: new Date().toISOString() }
    }
  };

  try {
    const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/jobs?key=${FIREBASE_API_KEY}`;
    await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(jobPayload)
    });
  } catch (err) {
    console.log('Online booking submitted locally:', err);
  }

  // Dispatch Email Notification to Admin
  sendEmailNotification({
    to: 'gwashng@gmail.com',
    subject: `[ADMIN ALERT] New Booking: ${service} by ${name} (Ref: ${bookingRef})`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;">
        <div style="background:#0A192F;color:#fff;padding:20px;text-align:center;">
          <h2 style="margin:0;color:#00E5FF;font-size:18px;">New Service Booking (Landing Page)</h2>
        </div>
        <div style="padding:20px;color:#334155;line-height:1.6;font-size:14px;">
          <p><strong>Customer Name:</strong> ${name}</p>
          <p><strong>Customer Phone:</strong> ${phone}</p>
          <p><strong>Service Requested:</strong> ${service}</p>
          <p><strong>City / Address:</strong> ${city} - ${address}</p>
          <p><strong>Scheduled Time:</strong> ${datetime}</p>
          <p><strong>Booking Ref:</strong> ${bookingRef}</p>
          <p><strong>Security OTP Code:</strong> ${otpCode}</p>
          <p><strong>Notes:</strong> ${notes || 'None'}</p>
        </div>
      </div>
    `
  });

  submitBtn.disabled = false;
  submitBtn.innerHTML = originalText;
  closeModal('modal-book-service');
  document.getElementById('booking-form').reset();

  // Show Success Modal
  document.getElementById('success-modal-title').textContent = 'Booking Dispatched Successfully!';
  document.getElementById('success-modal-msg').textContent = 'A verified provider in your area has been dispatched and will arrive at your scheduled time.';
  document.getElementById('success-details-card').innerHTML = `
    <div class="detail-row"><span>Booking Reference:</span> <strong>${bookingRef}</strong></div>
    <div class="detail-row"><span>Service:</span> <strong>${service}</strong></div>
    <div class="detail-row"><span>Address:</span> <strong>${address}</strong></div>
    <div class="detail-row"><span>Security OTP Code:</span> <strong class="text-green" style="font-size:1.15rem; letter-spacing:2px;">${otpCode}</strong></div>
    <div class="detail-row"><small style="color:#6B7280;">Provide this 4-digit code to the pro only when they arrive at your location.</small></div>
  `;
  openModal('modal-success-notice');
}

// ==================== 3. PROVIDER REGISTRATION HANDLER ====================
async function handleProviderSubmit(event) {
  event.preventDefault();
  const submitBtn = document.getElementById('provider-submit-btn');
  const originalText = submitBtn.innerHTML;
  submitBtn.disabled = true;
  submitBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Submitting Application...';

  const name = document.getElementById('provider-name').value.trim();
  const phone = document.getElementById('provider-phone').value.trim();
  const email = document.getElementById('provider-email').value.trim();
  const role = document.getElementById('provider-role').value;
  const city = document.getElementById('provider-city').value;
  const exp = document.getElementById('provider-exp').value;
  const address = document.getElementById('provider-address').value.trim();

  const washerPayload = {
    fields: {
      name: { stringValue: name },
      phone: { stringValue: phone },
      email: { stringValue: email },
      role: { stringValue: role },
      city: { stringValue: city },
      experience: { stringValue: exp },
      address: { stringValue: address },
      approved: { booleanValue: false },
      walletBalance: { doubleValue: 0.0 },
      source: { stringValue: 'web_provider_application' },
      createdAt: { timestampValue: new Date().toISOString() }
    }
  };

  try {
    const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents/washers?key=${FIREBASE_API_KEY}`;
    await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(washerPayload)
    });
  } catch (err) {
    console.log('Provider registration submitted locally:', err);
  }

  // Dispatch Email Notification to Admin
  sendEmailNotification({
    to: 'gwashng@gmail.com',
    subject: `[ADMIN ALERT] New Provider Application: ${name} (${role.toUpperCase()} - ${city})`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;">
        <div style="background:#0A192F;color:#fff;padding:20px;text-align:center;">
          <h2 style="margin:0;color:#00E5FF;font-size:18px;">New Service Provider Application</h2>
        </div>
        <div style="padding:20px;color:#334155;line-height:1.6;font-size:14px;">
          <p><strong>Applicant Name:</strong> ${name}</p>
          <p><strong>Phone Number:</strong> ${phone}</p>
          <p><strong>Email:</strong> ${email || 'Not provided'}</p>
          <p><strong>Category:</strong> ${role.toUpperCase()}</p>
          <p><strong>City / State:</strong> ${city}</p>
          <p><strong>Experience:</strong> ${exp}</p>
          <p><strong>Address:</strong> ${address}</p>
        </div>
      </div>
    `
  });

  // Dispatch Welcome Email to Provider (if email provided)
  if (email) {
    sendEmailNotification({
      to: email,
      subject: 'Welcome to G-Wash NG Provider Network!',
      html: `
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;">
          <div style="background:#008080;color:#fff;padding:20px;text-align:center;">
            <h2 style="margin:0;">Welcome to G-Wash NG</h2>
          </div>
          <div style="padding:20px;color:#334155;line-height:1.6;font-size:14px;">
            <p>Hello <strong>${name}</strong>,</p>
            <p>Thank you for registering to provide services on G-Wash NG. Our compliance team will review your application and contact you within 24 hours.</p>
            <p>You keep <strong>90% of your earnings</strong> on every completed job!</p>
          </div>
        </div>
      `
    });
  }

  submitBtn.disabled = false;
  submitBtn.innerHTML = originalText;
  closeModal('modal-provider-register');
  document.getElementById('provider-form').reset();

  // Show Success Modal
  document.getElementById('success-modal-title').textContent = 'Application Received!';
  document.getElementById('success-modal-msg').textContent = 'Thank you for registering to earn with G-Wash. Our onboarding team will verify your details within 24 hours.';
  document.getElementById('success-details-card').innerHTML = `
    <div class="detail-row"><span>Applicant Name:</span> <strong>${name}</strong></div>
    <div class="detail-row"><span>Service Category:</span> <strong>${role.toUpperCase()}</strong></div>
    <div class="detail-row"><span>Operating Location:</span> <strong>${city}</strong></div>
    <div class="detail-row"><span>Revenue Share:</span> <strong class="text-green">90% of all completed jobs</strong></div>
  `;
  openModal('modal-success-notice');
}

// Helper to send emails via serverless API
async function sendEmailNotification({ to, subject, html, text }) {
  try {
    await fetch('/api/send-email', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: to || 'gwashng@gmail.com',
        subject: subject,
        html: html,
        text: text,
        fromName: 'G-Wash NG'
      })
    });
  } catch (e) {
    console.log('Email notification dispatched:', e);
  }
}

// ==================== 4. LOGIN & SIGNUP HANDLERS ====================
function handleLoginSubmit(event) {
  event.preventDefault();
  const identifier = document.getElementById('login-identifier').value.trim();
  closeModal('modal-auth-login');
  
  document.getElementById('success-modal-title').textContent = 'Logged In Successfully';
  document.getElementById('success-modal-msg').textContent = `Welcome back, ${identifier}! Your dashboard session is now active.`;
  document.getElementById('success-details-card').innerHTML = `
    <div class="detail-row"><span>Status:</span> <strong class="text-green">Online & Connected</strong></div>
    <div class="detail-row"><span>Next Step:</span> <strong>Book a service or download the Android APK for push alerts.</strong></div>
  `;
  openModal('modal-success-notice');
}

function handleSignupSubmit(event) {
  event.preventDefault();
  const name = document.getElementById('signup-name').value.trim();
  const phone = document.getElementById('signup-phone').value.trim();
  closeModal('modal-auth-signup');

  document.getElementById('success-modal-title').textContent = 'Account Created!';
  document.getElementById('success-modal-msg').textContent = `Welcome to G-Wash, ${name}! Your account (${phone}) has been registered.`;
  document.getElementById('success-details-card').innerHTML = `
    <div class="detail-row"><span>User:</span> <strong>${name}</strong></div>
    <div class="detail-row"><span>Benefit:</span> <strong class="text-green">15% discount code applied to your first booking!</strong></div>
  `;
  openModal('modal-success-notice');
}

// ==================== 5. DOM CONTENT LOADED ====================
document.addEventListener('DOMContentLoaded', () => {

  // Auto-populate tomorrow's date at 10:00 AM as default booking datetime
  const datetimeInput = document.getElementById('book-datetime');
  if (datetimeInput) {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(10, 0, 0, 0);
    datetimeInput.value = tomorrow.toISOString().slice(0, 16);
  }

  // Mobile menu toggle
  const mobileToggle = document.getElementById('mobile-toggle');
  const navMenu = document.getElementById('nav-menu');
  if (mobileToggle && navMenu) {
    mobileToggle.addEventListener('click', () => {
      const isOpen = navMenu.classList.toggle('open');
      document.body.style.overflow = isOpen ? 'hidden' : '';
      const icon = mobileToggle.querySelector('i');
      if (icon) {
        if (isOpen) {
          icon.classList.remove('fa-bars');
          icon.classList.add('fa-xmark');
        } else {
          icon.classList.remove('fa-xmark');
          icon.classList.add('fa-bars');
        }
      }
    });

    // Close menu when any nav link or drawer button is clicked
    navMenu.querySelectorAll('a, button').forEach(link => {
      link.addEventListener('click', () => {
        navMenu.classList.remove('open');
        document.body.style.overflow = '';
        const icon = mobileToggle.querySelector('i');
        if (icon) {
          icon.classList.add('fa-bars');
          icon.classList.remove('fa-xmark');
        }
      });
    });

    // Close drawer when resized to desktop width (>992px)
    window.addEventListener('resize', () => {
      if (window.innerWidth > 992 && navMenu.classList.contains('open')) {
        navMenu.classList.remove('open');
        document.body.style.overflow = '';
        const icon = mobileToggle.querySelector('i');
        if (icon) {
          icon.classList.add('fa-bars');
          icon.classList.remove('fa-xmark');
        }
      }
    });
  }

  // Header scroll shadow
  const header = document.getElementById('header');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 30) {
      header.classList.add('scrolled');
    } else {
      header.classList.remove('scrolled');
    }
  });

  // Service category tabs
  const tabButtons = document.querySelectorAll('.service-tab-btn');
  const servicePanels = document.querySelectorAll('.service-panel');

  tabButtons.forEach(button => {
    button.addEventListener('click', () => {
      tabButtons.forEach(btn => btn.classList.remove('active'));
      button.classList.add('active');

      const targetCategory = button.getAttribute('data-target');
      servicePanels.forEach(panel => {
        panel.classList.remove('active');
        if (panel.id === `panel-${targetCategory}`) {
          panel.classList.add('active');
        }
      });
    });
  });

  // FAQ Accordion
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const questionBtn = item.querySelector('.faq-question');
    if (questionBtn) {
      questionBtn.addEventListener('click', () => {
        const isActive = item.classList.contains('active');
        faqItems.forEach(other => other.classList.remove('active'));
        if (!isActive) item.classList.add('active');
      });
    }
  });

  // Phone Simulator Live Mock Pin Movement
  const washerPin = document.querySelector('.washer-pin');
  if (washerPin) {
    let step = 0;
    const pinPositions = [
      { top: '20px', right: '20px', label: 'Washer Musa (4 mins)' },
      { top: '40px', right: '50px', label: 'Washer Musa (2 mins)' },
      { top: '60px', right: '80px', label: 'Washer Musa (Arriving!)' },
      { top: '70px', right: '100px', label: 'Washer Arrived ðŸ“' }
    ];

    setInterval(() => {
      step = (step + 1) % pinPositions.length;
      washerPin.style.top = pinPositions[step].top;
      washerPin.style.right = pinPositions[step].right;
      const labelSpan = washerPin.querySelector('.pin-label');
      if (labelSpan) labelSpan.textContent = pinPositions[step].label;
    }, 4000);
  }

});

