importScripts('https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.1/firebase-messaging-compat.js');

self.addEventListener('message', (event) => {
    if (event.data?.type === 'FIREBASE_CONFIG') {
        if (!firebase.apps.length) {
            firebase.initializeApp(event.data.config);
        }
        const messaging = firebase.messaging();
        messaging.onBackgroundMessage((payload) => {
            self.registration.showNotification(
                payload.notification?.title || 'Meatvo Admin',
                {
                    body: payload.notification?.body || '',
                    icon: '/logo.png'
                }
            );
        });
    }
});
