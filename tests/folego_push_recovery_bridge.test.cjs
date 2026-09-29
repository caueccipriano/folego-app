// No browser, push gateway, Supabase connection or real customer data.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const { join } = require('node:path');

const bridgeScript = readFileSync(
  join(__dirname, '..', 'folego_push_bridge.js'), 'utf8',
);

function syntheticBridge({
  permission = 'granted',
  existing = {
    endpoint: 'https://push.synthetic.invalid/previously-approved',
    keys: { p256dh: 'fictional-public', auth: 'fictional-secret' },
  },
  strictGesture = false,
  userAgent = 'fictional-Test-PWA',
  standalone = true,
} = {}) {
  let prompts = 0;
  let registrations = 0;
  let newSubscriptions = 0;
  let unsubscribes = 0;
  let existingLookups = 0;
  let gestureActive = false;
  const calls = {
    withTap: (action) => {
      gestureActive = true;
      try { return action(); } finally { gestureActive = false; }
    },
    prompts: () => prompts,
    registrations: () => registrations,
    newSubscriptions: () => newSubscriptions,
    unsubscribes: () => unsubscribes,
    existingLookups: () => existingLookups,
  };

  let subscription = existing && {
    endpoint: existing.endpoint,
    toJSON() { return existing; },
    async unsubscribe() { unsubscribes++; subscription = null; return true; },
  };
  const registration = {
    waiting: null,
    async update() {},
    pushManager: {
      async getSubscription() { existingLookups++; return subscription; },
      async subscribe() {
        if (strictGesture && !gestureActive) {
          throw new Error('subscribe_missing_direct_user_gesture');
        }
        newSubscriptions++;
        subscription = {
          endpoint: 'https://push.synthetic.invalid/new-identity-only',
          toJSON() {
            return {
              endpoint: this.endpoint,
              keys: { p256dh: 'new-fake', auth: 'new-fake' },
            };
          },
          async unsubscribe() { unsubscribes++; subscription = null; return true; },
        };
        return subscription;
      },
    },
  };
  const context = {
    URL,
    JSON,
    Uint8Array,
    atob,
    window: {
      addEventListener() {},
      matchMedia: () => ({ matches: standalone }),
    },
    Notification: {
      get permission() { return permission; },
      requestPermission() {
        if (strictGesture && !gestureActive) {
          throw new Error('permission_missing_direct_user_gesture');
        }
        prompts++;
        permission = 'granted';
        return Promise.resolve('granted');
      },
    },
    PushManager: class PushManager {},
    navigator: {
      userAgent,
      standalone,
      serviceWorker: {
        async getRegistration() { return registration; },
        async register() { registrations++; return registration; },
      },
    },
    document: {
      baseURI: 'https://push.synthetic.invalid/folego/',
      readyState: 'loading',
      addEventListener() {},
    },
  };
  context.window.PushManager = context.PushManager;
  context.window.Notification = context.Notification;
  vm.runInNewContext(bridgeScript, context, {
    filename: 'folego_push_bridge.js',
  });
  return { api: context.window, calls };
}

test('already approved local subscription is peeked without prompts or subscribe', async () => {
  const { api, calls } = syntheticBridge();
  const peek = JSON.parse(await api.folegoPushPeekExistingSubscription());
  assert.equal(peek.status, 'granted');
  assert.equal(
    peek.subscription.endpoint,
    'https://push.synthetic.invalid/previously-approved',
  );
  assert.equal(calls.prompts(), 0);
  assert.equal(calls.registrations(), 0);
  assert.equal(calls.newSubscriptions(), 0);
  assert.equal(calls.unsubscribes(), 0);
  assert.equal(calls.existingLookups(), 1);
});

test('browser permission alone does not create a subscription on peek', async () => {
  const { api, calls } = syntheticBridge({ existing: null });
  const peek = JSON.parse(await api.folegoPushPeekExistingSubscription());
  assert.equal(peek.status, 'granted');
  assert.equal(peek.subscription, null);
  assert.equal(calls.newSubscriptions(), 0);
  assert.equal(calls.prompts(), 0);
});

test('denied browser permission cannot inspect or create endpoints', async () => {
  const { api, calls } = syntheticBridge({ permission: 'denied' });
  const peek = JSON.parse(await api.folegoPushPeekExistingSubscription());
  assert.equal(peek.status, 'denied');
  assert.equal(peek.subscription, null);
  assert.equal(calls.existingLookups(), 0);
  assert.equal(calls.prompts(), 0);
  assert.equal(calls.newSubscriptions(), 0);
});

test('notification permission must never be prompted during startup probe', async () => {
  const { api, calls } = syntheticBridge({ permission: 'default' });
  const peek = JSON.parse(await api.folegoPushPeekExistingSubscription());
  assert.equal(peek.status, 'notDetermined');
  assert.equal(peek.subscription, null);
  assert.equal(calls.prompts(), 0);
  assert.equal(calls.newSubscriptions(), 0);
});

test('explicit opt-in remains a separate action that can create a new endpoint', async () => {
  const { api, calls } = syntheticBridge({ existing: null });
  const manual = JSON.parse(await api.folegoPushRequestAndSubscribe());
  assert.equal(manual.status, 'granted');
  assert.equal(
    manual.subscription.endpoint,
    'https://push.synthetic.invalid/new-identity-only',
  );
  assert.equal(calls.newSubscriptions(), 1);
  assert.equal(calls.prompts(), 0);
});

test('a user-initiated previous-device unsubscribe leaves no local endpoint', async () => {
  const { api, calls } = syntheticBridge();
  const response = JSON.parse(await api.folegoPushUnsubscribe());
  assert.equal(
    response.endpoint,
    'https://push.synthetic.invalid/previously-approved',
  );
  const peek = JSON.parse(await api.folegoPushPeekExistingSubscription());
  assert.equal(peek.subscription, null);
  assert.equal(calls.unsubscribes(), 1);
});

test('iPhone browser tab does not offer Web Push outside installed Home Screen app', async () => {
  const { api, calls } = syntheticBridge({
    permission: 'default', existing: null, strictGesture: true,
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)',
    standalone: false,
  });
  const result = JSON.parse(await api.folegoPushPermissionFromTap());
  assert.equal(result.status, 'unsupported');
  assert.equal(calls.prompts(), 0);
  assert.equal(calls.newSubscriptions(), 0);
});

test('installed iPhone requests permission DIRECTLY from the first tap', async () => {
  const { api, calls } = syntheticBridge({
    permission: 'default', existing: null, strictGesture: true,
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)',
    standalone: true,
  });
  const preflight = JSON.parse(await api.folegoPushPrepareTap());
  assert.equal(preflight.ready, true);
  assert.equal(calls.prompts(), 0);
  assert.equal(calls.newSubscriptions(), 0);

  const requested = calls.withTap(() => api.folegoPushPermissionFromTap());
  assert.equal(calls.prompts(), 1, 'must start synchronously in tap');
  const response = JSON.parse(await requested);
  assert.equal(response.status, 'permissionGrantedNeedsActivation');
  assert.equal(calls.newSubscriptions(), 0, 'must not auto-subscribe after prompt');
});

test('second installed-iPhone tap starts subscribe SYNCHRONOUSLY', async () => {
  const { api, calls } = syntheticBridge({
    permission: 'granted', existing: null, strictGesture: true,
    userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)',
    standalone: true,
  });
  assert.equal(JSON.parse(await api.folegoPushPrepareTap()).ready, true);
  const pending = calls.withTap(() => api.folegoPushSubscribeFromTap());
  assert.equal(calls.newSubscriptions(), 1, 'subscribe must start before tap returns');
  const response = JSON.parse(await pending);
  assert.equal(response.status, 'granted');
  assert.equal(response.subscription.endpoint, 'https://push.synthetic.invalid/new-identity-only');
  assert.equal(calls.prompts(), 0);
});

test('without completed prewarm, a tap fails safely rather than delaying subscription', async () => {
  const { api, calls } = syntheticBridge({
    permission: 'granted', existing: null, strictGesture: true,
  });
  const pending = calls.withTap(() => api.folegoPushSubscribeFromTap());
  assert.equal(JSON.parse(await pending).status, 'needsPreparation');
  assert.equal(calls.newSubscriptions(), 0);
  assert.equal(calls.prompts(), 0);
});
