(() => {
  const VAPID_PUBLIC_KEY = 'BH7q2FubEJ5uZqSuZli0usVvqP9dbGyFoGSZu03YDryy_IKuZoVqHzC_9geURT5eNZqmpcAMwYvttD6Pi4zSBiY';

  let registrationPromise = null;

  function supported() {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }

  function status() {
    if (!supported()) return 'unsupported';
    if (Notification.permission === 'granted') return 'granted';
    if (Notification.permission === 'denied') return 'denied';
    return 'notDetermined';
  }

  function urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  async function registerWorkerOnce() {
    if (!('serviceWorker' in navigator)) return null;
    if (registrationPromise) return registrationPromise;

    registrationPromise = (async () => {
      const workerUrl = new URL('folego_push_sw.js', document.baseURI);
      const registration = await navigator.serviceWorker.register(workerUrl.href, {
        scope: './',
        updateViaCache: 'none',
      });

      // Always ask the browser for the latest worker on app launch. Previously
      // this only happened after the user requested push permission, which let
      // old service workers survive across deploys.
      await registration.update();

      if (registration.waiting) {
        registration.waiting.postMessage({ type: 'SKIP_WAITING' });
      }

      return registration;
    })();

    try {
      return await registrationPromise;
    } catch (error) {
      registrationPromise = null;
      throw error;
    }
  }

  async function ensureLatestWorker() {
    try {
      await registerWorkerOnce();
    } catch (_) {
      // Push setup must never block app startup.
    }
  }

  // Refresh the worker on every app load, independently of notification
  // permission. This keeps installed PWAs aligned with the deployed build.
  if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', ensureLatestWorker, { once: true });
  } else {
    void ensureLatestWorker();
  }

  window.folegoPushGetStatus = async function () {
    return status();
  };

  window.folegoPushRequestAndSubscribe = async function () {
    if (!supported()) {
      return JSON.stringify({ status: 'unsupported' });
    }

    let permission = Notification.permission;
    if (permission === 'default') {
      permission = await Notification.requestPermission();
    }
    if (permission !== 'granted') {
      return JSON.stringify({ status: permission === 'denied' ? 'denied' : 'notDetermined' });
    }

    const registration = await registerWorkerOnce();
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
      });
    }

    return JSON.stringify({
      status: 'granted',
      subscription: subscription.toJSON(),
      userAgent: navigator.userAgent,
    });
  };

  window.folegoPushUnsubscribe = async function () {
    if (!supported()) return JSON.stringify({ status: 'unsupported' });
    const registration = await navigator.serviceWorker.getRegistration('./');
    if (!registration) return JSON.stringify({ status: status(), endpoint: null });
    const subscription = await registration.pushManager.getSubscription();
    if (!subscription) return JSON.stringify({ status: status(), endpoint: null });
    const endpoint = subscription.endpoint;
    await subscription.unsubscribe();
    return JSON.stringify({ status: status(), endpoint });
  };
})();
