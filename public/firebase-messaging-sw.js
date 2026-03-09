importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js');
// // Initialize the Firebase app in the service worker by passing the generated config

const firebaseConfig = {
  apiKey: "AIzaSyD0D8vrMOf592N0BO_PWWroMs0XTkgBgns",
  authDomain: "kisiden-com34.firebaseapp.com",
  projectId: "kisiden-com34",
  storageBucket: "kisiden-com34.firebasestorage.app",
  messagingSenderId: "768619644511",
  appId: "1:768619644511:web:4d1d77c7649045ec0efdea",
  measurementId: "G-17YWD7QTN4"
};

firebase?.initializeApp(firebaseConfig)

// Retrieve firebase messaging
const messaging = firebase.messaging();

self.addEventListener('install', function (event) {
    console.log('Hello world from the Service Worker :call_me_hand:');
});


