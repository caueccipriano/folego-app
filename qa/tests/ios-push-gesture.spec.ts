import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// A real WebKit ENGINE running an iPhone-sized Playwright browser context,
// with fictional browser APIs. This does NOT impersonate a physical iPhone,
// ask the real OS for permission, or access real Supabase/Push data.
const bridge = readFileSync(
  resolve(process.cwd(), '../folego_flutter/web/folego_push_bridge.js'),
  'utf8',
);

test('iPhone WebKit: separate explicit taps start permission and subscribe synchronously', async ({
  page,
  browserName,
}) => {
  test.skip(browserName !== 'webkit', 'This test targets WebKit engine.');
  await page.setContent(
    '<base href="https://synthetic.invalid/folego/">' +
      '<button id="grant">Permitir notificações</button>' +
      '<button id="subscribe">Ativar neste dispositivo</button>',
  );

  await page.evaluate(() => {
    const w = window as typeof window & {
      __clickActive?: boolean;
      __trace?: Array<{ operation: string; synchronous: boolean }>;
      __permissionResult?: string;
      __subscribeResult?: string;
      folegoPushPrepareTap?: () => Promise<string>;
      folegoPushPermissionFromTap?: () => Promise<string>;
      folegoPushSubscribeFromTap?: () => Promise<string>;
    };
    w.__trace = [];
    w.__clickActive = false;

    let permission = 'default';
    let stored: null | { endpoint: string; toJSON: () => object } = null;
    const registration = {
      waiting: null,
      update: async () => {},
      pushManager: {
        getSubscription: async () => stored,
        subscribe: () => {
          w.__trace!.push({
            operation: 'subscribe',
            synchronous: w.__clickActive === true,
          });
          stored = {
            endpoint: 'https://push.synthetic.invalid/ios-mock',
            toJSON: () => ({
              endpoint: 'https://push.synthetic.invalid/ios-mock',
              keys: { p256dh: 'fictional-key', auth: 'fictional-secret' },
            }),
          };
          return Promise.resolve(stored);
        },
      },
    };

    Object.defineProperty(navigator, 'standalone', {
      value: true,
      configurable: true,
    });
    Object.defineProperty(navigator, 'serviceWorker', {
      configurable: true,
      value: {
        getRegistration: async () => registration,
        register: async () => registration,
      },
    });
    Object.defineProperty(window, 'PushManager', {
      configurable: true,
      value: function PushManager() {},
    });
    Object.defineProperty(window, 'Notification', {
      configurable: true,
      value: {
        get permission() { return permission; },
        requestPermission: () => {
          w.__trace!.push({
            operation: 'permission',
            synchronous: w.__clickActive === true,
          });
          permission = 'granted';
          return Promise.resolve('granted');
        },
      },
    });
  });

  await page.addScriptTag({ content: bridge });
  const prepared = await page.evaluate(async () => {
    const api = window as typeof window & {
      folegoPushPrepareTap: () => Promise<string>;
    };
    return JSON.parse(await api.folegoPushPrepareTap());
  });
  expect(prepared.ready).toBe(true);

  await page.evaluate(() => {
    const api = window as typeof window & {
      __clickActive: boolean;
      __permissionResult: string;
      __subscribeResult: string;
      folegoPushPermissionFromTap: () => Promise<string>;
      folegoPushSubscribeFromTap: () => Promise<string>;
    };
    document.getElementById('grant')!.addEventListener('click', () => {
      api.__clickActive = true;
      const pending = api.folegoPushPermissionFromTap();
      api.__clickActive = false;
      void pending.then((value) => {
        api.__permissionResult = JSON.parse(value).status;
      });
    });
    document.getElementById('subscribe')!.addEventListener('click', () => {
      api.__clickActive = true;
      const pending = api.folegoPushSubscribeFromTap();
      api.__clickActive = false;
      void pending.then((value) => {
        api.__subscribeResult = JSON.parse(value).status;
      });
    });
  });

  await page.getByRole('button', { name: 'Permitir notificações' }).click();
  await expect.poll(() =>
    page.evaluate(() => (window as typeof window & {
      __permissionResult?: string
    }).__permissionResult)
  ).toBe('permissionGrantedNeedsActivation');

  const first = await page.evaluate(() => (window as typeof window & {
    __trace: Array<{ operation: string; synchronous: boolean }>
  }).__trace);
  expect(first).toEqual([{ operation: 'permission', synchronous: true }]);

  await page.getByRole('button', { name: 'Ativar neste dispositivo' }).click();
  await expect.poll(() =>
    page.evaluate(() => (window as typeof window & {
      __subscribeResult?: string
    }).__subscribeResult)
  ).toBe('granted');

  const both = await page.evaluate(() => (window as typeof window & {
    __trace: Array<{ operation: string; synchronous: boolean }>
  }).__trace);
  expect(both).toEqual([
    { operation: 'permission', synchronous: true },
    { operation: 'subscribe', synchronous: true },
  ]);
});

test('iPhone WebKit in normal Safari tab cannot prompt or register Web Push', async ({
  page,
  browserName,
}) => {
  test.skip(browserName !== 'webkit', 'This test targets WebKit engine.');
  await page.setContent('<base href="https://synthetic.invalid/folego/">');
  await page.evaluate(() => {
    Object.defineProperty(navigator, 'standalone', {
      value: false,
      configurable: true,
    });
    Object.defineProperty(window, 'PushManager', {
      value: function PushManager() {},
      configurable: true,
    });
    Object.defineProperty(window, 'Notification', {
      value: { permission: 'default', requestPermission: () => {
        throw new Error('Safari tab must never prompt');
      } },
      configurable: true,
    });
    Object.defineProperty(navigator, 'serviceWorker', {
      value: { getRegistration: async () => null },
      configurable: true,
    });
  });
  await page.addScriptTag({ content: bridge });
  const result = await page.evaluate(async () => {
    const api = window as typeof window & {
      folegoPushPermissionFromTap: () => Promise<string>;
    };
    return JSON.parse(await api.folegoPushPermissionFromTap());
  });
  expect(result.status).toBe('unsupported');
});
