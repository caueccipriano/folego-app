(() => {
  const VAPID_PUBLIC_KEY = 'BH7q2FubEJ5uZqSuZli0usVvqP9dbGyFoGSZu03YDryy_IKuZoVqHzC_9geURT5eNZqmpcAMwYvttD6Pi4zSBiY';

  let registrationPromise = null;
  let readyRegistration = null;
  let readySubscription = null;

  function needsHomeScreenInstall() {
    const ios = /iPhone|iPad|iPod/.test(navigator.userAgent || '');
    if (!ios) return false;
    const standaloneDisplay = typeof window.matchMedia === 'function' &&
      window.matchMedia('(display-mode: standalone)').matches;
    return !standaloneDisplay && navigator.standalone !== true;
  }

  function supported() {
    return 'serviceWorker' in navigator && 'PushManager' in window &&
      'Notification' in window && !needsHomeScreenInstall();
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

  // Pre-warm the service worker and subscription before a future tap.
  // On WebKit, the tap must START subscribe() without awaiting setup.
  async function prepareForTap() {
    const registration = await registerWorkerOnce();
    if (!registration) return false;
    readyRegistration = registration;
    readySubscription = await registration.pushManager.getSubscription();
    return true;
  }

  async function ensureLatestWorker() {
    try {
      await prepareForTap();
    } catch (_) {
      // Push setup must never block app startup.
    }
  }

  window.folegoPushPrepareTap = async function () {
    if (!supported()) return JSON.stringify({ ready: false, status: status() });
    try {
      const ready = await prepareForTap();
      return JSON.stringify({ ready, status: status() });
    } catch (_) {
      return JSON.stringify({ ready: false, status: status() });
    }
  };

  // These two APIs must be CALLED synchronously from the Flutter tap.
  // Permission prompts and PushManager.subscribe() never happen in an
  // automatic login effect or after a network preflight await.
  window.folegoPushPermissionFromTap = function () {
    if (!supported()) {
      return Promise.resolve(JSON.stringify({ status: 'unsupported' }));
    }
    if (Notification.permission === 'denied') {
      return Promise.resolve(JSON.stringify({ status: 'denied' }));
    }
    if (Notification.permission === 'granted') {
      return Promise.resolve(JSON.stringify({ status: 'granted' }));
    }
    const requested = Notification.requestPermission();
    return Promise.resolve(requested).then((permission) => JSON.stringify({
      status: permission === 'granted'
        ? 'permissionGrantedNeedsActivation'
        : permission === 'denied' ? 'denied' : 'notDetermined',
    }));
  };

  window.folegoPushSubscribeFromTap = function () {
    if (!supported()) return Promise.resolve(JSON.stringify({ status: 'unsupported' }));
    if (Notification.permission !== 'granted') {
      return Promise.resolve(JSON.stringify({ status: status() }));
    }
    if (!readyRegistration) {
      return Promise.resolve(JSON.stringify({ status: 'needsPreparation' }));
    }

    // This is the important iPhone gesture boundary. Any asynchronous
    // server ownership check, service-worker registration, or browser
    // subscription inspection MUST already be finished before this call.
    const pending = readySubscription
      ? Promise.resolve(readySubscription)
      : readyRegistration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
        });
    return Promise.resolve(pending).then((subscription) => {
      readySubscription = subscription;
      return JSON.stringify({
        status: 'granted',
        subscription: subscription.toJSON(),
        userAgent: navigator.userAgent,
      });
    });
  };

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

  // Read-only probe for previously granted Push permission and a locally
  // existing subscription. Never prompts, subscribes, or reuses an endpoint
  // for a newly signed-in person based on browser permission alone.
  window.folegoPushPeekExistingSubscription = async function () {
    if (!supported() || Notification.permission !== 'granted') {
      return JSON.stringify({ status: status(), subscription: null });
    }
    const registration = await navigator.serviceWorker.getRegistration('./');
    const subscription = registration
      ? await registration.pushManager.getSubscription()
      : null;
    if (registration) {
      readyRegistration = registration;
      readySubscription = subscription;
    }
    return JSON.stringify({
      status: 'granted',
      subscription: subscription ? subscription.toJSON() : null,
      userAgent: navigator.userAgent,
    });
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
    readySubscription = null;
    return JSON.stringify({ status: status(), endpoint });
  };
})();
