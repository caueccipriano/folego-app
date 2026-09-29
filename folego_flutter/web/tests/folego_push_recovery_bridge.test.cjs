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
} = {}) {
  let prompts = 0;
  let registrations = 0;
  let newSubscriptions = 0;
  let unsubscribes = 0;
  let existingLookups = 0;
  const calls = {
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
    window: { addEventListener() {} },
    Notification: {
      permission,
      async requestPermission() { prompts++; return 'granted'; },
    },
    PushManager: class PushManager {},
    navigator: {
      userAgent: 'fictional-Test-PWA',
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
