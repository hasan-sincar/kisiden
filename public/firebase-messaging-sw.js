importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js');
// // Initialize the Firebase app in the service worker by passing the generated config

const firebaseConfig = {
    apiKey: "AIzaSyD_Ee9lZgqo6GHWlJ7Ps4APQDIPnPXXlIQ",
    authDomain: "kisiden-1.firebaseapp.com",
    projectId: "kisiden-1",
    storageBucket: "kisiden-1.firebasestorage.app",
    messagingSenderId: "9629773921",
    appId: "1:9629773921:web:4c15e1d893a0b0c07f3a20",
    measurementId: "G-BF1DNF4ZFM"
};

firebase?.initializeApp(firebaseConfig)

// Retrieve firebase messaging
const messaging = firebase.messaging();

self.addEventListener('install', function (event) {
    console.log('Hello world from the Service Worker :call_me_hand:');
});
