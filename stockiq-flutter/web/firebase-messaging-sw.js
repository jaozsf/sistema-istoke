// Service worker do Firebase Cloud Messaging para push em background no
// Flutter Web. Carregado automaticamente pelo plugin firebase_messaging_web
// a partir da raiz do app (precisa ficar exatamente em /firebase-messaging-sw.js).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Mesma config de lib/firebase_options.dart (DefaultFirebaseOptions.web) --
// não é segredo, só identifica o projeto Firebase.
firebase.initializeApp({
  apiKey: 'AIzaSyAkEiFh9ALqPbh-1r9ws6m6Yk4GCa2Nw_A',
  appId: '1:840917493129:web:7d68474287aebc393f2d58',
  messagingSenderId: '840917493129',
  projectId: 'istoke-b9ba9',
  authDomain: 'istoke-b9ba9.firebaseapp.com',
  storageBucket: 'istoke-b9ba9.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification || {};
  self.registration.showNotification(title || 'StockIQ', {
    body: body || '',
    icon: '/icons/Icon-192.png',
  });
});
