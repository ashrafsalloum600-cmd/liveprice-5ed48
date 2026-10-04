importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: 'AIzaSyBnCfG4ngEJHKKG8s_s5mV3dpPukwgJSdg',
    appId: '1:454939057507:web:120a4a32a95d84705f0756',
    messagingSenderId: '454939057507',
    projectId: 'liveprice-5ed48',
    authDomain: 'liveprice-5ed48.firebaseapp.com',
    storageBucket: 'liveprice-5ed48.firebasestorage.app',
    measurementId: 'G-DBT7PV35J7'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    const notificationTitle = payload.notification?.title || 'New notification';
    const notificationOptions = {
        body: payload.notification?.body || '',
        icon: '/icons/Icon-192.png'
    };

    return self.registration.showNotification(notificationTitle, notificationOptions);
});
