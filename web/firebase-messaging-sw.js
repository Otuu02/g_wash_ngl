// Service worker for Firebase Cloud Messaging on Web
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw",
  authDomain: "g-wash-ng.firebaseapp.com",
  projectId: "g-wash-ng",
  storageBucket: "g-wash-ng.firebasestorage.app",
  messagingSenderId: "268073858735",
  appId: "1:268073858735:web:e0d0510cdee83a1506065a"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // Silent background notification handler
});
