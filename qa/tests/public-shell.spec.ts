import { expect, test } from '@playwright/test';
import { capture, enableFlutterAccessibility, openFolego } from './helpers';

test.describe('Fôlego public PWA shell', () => {
  test('opens a local demo without login or financial writes', async ({ page }, testInfo) => {
    const financialWrites: string[] = [];
    page.on('request', request => {
      if (['POST', 'PATCH', 'PUT', 'DELETE'].includes(request.method()) &&
          /supabase\.co\/(rest|functions)\/v1/.test(request.url())) {
        financialWrites.push(request.url());
      }
    });
    await openFolego(page);
    await enableFlutterAccessibility(page, Boolean(testInfo.project.use.hasTouch));
    await page.getByRole('button', { name: 'experimentar com dados fictícios', exact: true }).click();
    await expect(page.getByText('experimente à vontade', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'buscar nos exemplos', exact: true }).click();
    const field = page.getByRole('textbox').first();
    await field.fill('mercado');
    await expect(page.getByRole('button', { name: /mercado da semana/i }).first()).toBeVisible();
    await capture(page, testInfo, 'demo-search');
    expect(financialWrites).toEqual([]);
  });

  test('boots cleanly without viewport overflow', async ({ page }, testInfo) => {
    const pageErrors = await openFolego(page);
    const geometry = await page.evaluate(() => ({
      innerWidth: window.innerWidth,
      innerHeight: window.innerHeight,
      scrollWidth: document.documentElement.scrollWidth,
      scrollHeight: document.documentElement.scrollHeight,
    }));

    expect(geometry.scrollWidth).toBeLessThanOrEqual(geometry.innerWidth + 2);
    expect(geometry.innerWidth).toBe(testInfo.project.use.viewport?.width);
    expect(geometry.innerHeight).toBe(testInfo.project.use.viewport?.height);
    expect(pageErrors, pageErrors.join('\n')).toEqual([]);

    await capture(page, testInfo, 'login-shell');
  });

  test('has installable PWA metadata and mobile-safe viewport', async ({
    page,
    request,
    baseURL,
  }) => {
    await openFolego(page);

    const htmlResponse = await request.get(baseURL!);
    expect(htmlResponse.ok()).toBeTruthy();
    const html = await htmlResponse.text();
    const viewport = html.match(
      /<meta[^>]+name=["']viewport["'][^>]+content=["']([^"']+)["']/i,
    )?.[1];
    expect(viewport).toContain('width=device-width');
    expect(viewport).toContain('viewport-fit=cover');
    expect(viewport ?? '').not.toContain('user-scalable=no');

    const manifestHref = await page
      .locator('link[rel="manifest"]')
      .getAttribute('href');
    expect(manifestHref).toMatch(/^manifest\.json\?v=[0-9a-f]{40}$/);

    const manifestUrl = new URL(manifestHref!, baseURL!).toString();
    const manifestResponse = await request.get(manifestUrl);
    expect(manifestResponse.ok()).toBeTruthy();

    const manifest = await manifestResponse.json();
    expect(manifest.name).toBe('Fôlego');
    expect(manifest.display).toBe('standalone');
    expect(manifest.background_color).toBe('#F5F1E8');
    expect(manifest.theme_color).toBe('#F5F1E8');
    expect(manifest.icons).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ sizes: '192x192', purpose: 'maskable' }),
        expect.objectContaining({ sizes: '512x512', purpose: 'maskable' }),
      ]),
    );

    const sw = await request.get(new URL('folego_push_sw.js', baseURL!).toString());
    expect(sw.ok()).toBeTruthy();

    const appleIcon = page.locator('link[rel="apple-touch-icon"]');
    await expect(appleIcon).toHaveCount(1);
    const appleIconHref = await appleIcon.getAttribute('href');
    expect(appleIconHref).toMatch(/^data:image\/png;base64,[A-Za-z0-9+/=]+$/);

    // iOS 27 native Add-to-Home-Screen may fail an independent network fetch.
    // The approved 180px PNG is embedded in HTML at build time, byte-for-byte
    // equal to the publicly available legacy file.
    const iconPng = Buffer.from(appleIconHref!.split(',')[1], 'base64');
    const iconResponse = await request.get(
      new URL('apple-touch-icon-ios-v2.png', baseURL!).toString(),
    );
    expect(iconResponse.ok()).toBeTruthy();
    expect(iconResponse.headers()['content-type']).toContain('image/png');
    expect(iconPng.equals(await iconResponse.body())).toBe(true);
    expect(iconPng.subarray(0, 8).toString('hex')).toBe('89504e470d0a1a0a');
    expect(iconPng.readUInt32BE(16)).toBe(180);
    expect(iconPng.readUInt32BE(20)).toBe(180);

    // Ensure WebKit/Chromium can actually decode the image and that the icon
    // contains the purple piggy graphic, not just a blank beige square.
    const iconPixels = await page.evaluate(async (href) => {
      const image = new Image();
      image.src = new URL(href, document.baseURI).href;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = 180;
      canvas.height = 180;
      const context = canvas.getContext('2d');
      if (!context) throw new Error('Canvas 2D unavailable');
      context.drawImage(image, 0, 0);
      const data = context.getImageData(0, 0, 180, 180).data;
      const colors = new Set<string>();
      let opaque = 0;
      for (let y = 10; y < 180; y += 20) {
        for (let x = 10; x < 180; x += 20) {
          const offset = (y * 180 + x) * 4;
          colors.add(
            [data[offset], data[offset + 1], data[offset + 2]].join(','),
          );
          if (data[offset + 3] === 255) opaque += 1;
        }
      }
      return { width: image.naturalWidth, height: image.naturalHeight,
        colors: colors.size, opaque };
    }, appleIconHref!);
    expect(iconPixels.width).toBe(180);
    expect(iconPixels.height).toBe(180);
    expect(iconPixels.colors).toBeGreaterThan(6);
    expect(iconPixels.opaque).toBeGreaterThan(40);

    const manifestAppleIcon = manifest.icons.find(
      (icon: { src: string }) => icon.src === 'apple-touch-icon-ios-v2.png',
    );
    expect(manifestAppleIcon?.sizes).toBe('180x180');
  });

  test('detects new PWA version and offers a safe user-controlled update', async ({
    page,
    baseURL,
  }) => {
    await page.route('**/folego_version.json?*', async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ version: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' }),
      });
    });

    await page.goto(baseURL!);
    const notice = page.locator('#folego-new-version-notice');
    await expect(notice).toBeVisible();
    await expect(notice).toContainText('nova versão disponível');
    await expect(notice).toContainText(/seus dados continuam salvos/i);

    await notice.getByRole('button', { name: 'depois' }).click();
    await expect(notice).toHaveCount(0);
  });

  test('prelaunch landing is reachable with legal links and no checkout', async ({
    request,
    baseURL,
  }) => {
    const response = await request.get(new URL('launch/', baseURL!).toString());
    expect(response.ok()).toBeTruthy();
    const html = await response.text();
    expect(html).toContain('começar gratuitamente');
    expect(html).toContain('R$ 9,90');
    expect(html).toContain('cobrança comercial ainda está em preparação');
    expect(html).toContain('../legal/privacy.html');
    expect(html).not.toContain('checkout.asaas.com');
  });

  test('second landing presents plans without payment collection', async ({
    request,
    baseURL,
  }) => {
    const response = await request.get(new URL('conheca/', baseURL!).toString());
    expect(response.ok()).toBeTruthy();
    const html = await response.text();
    expect(html).toContain('Quanto posso gastar sem apertar amanhã?');
    expect(html).toContain('R$ 9,90');
    expect(html).toContain('Assinaturas em preparação');
    expect(html).toContain('../legal/privacy.html');
    expect(html).not.toContain('checkout.asaas.com');
  });

  test('keeps Flutter surface inside the viewport after resize', async ({
    page,
  }, testInfo) => {
    await openFolego(page);
    const initial = testInfo.project.use.viewport!;
    const narrowWidth = Math.max(320, initial.width - 24);

    await page.setViewportSize({
      width: narrowWidth,
      height: initial.height,
    });
    await page.waitForTimeout(300);

    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - window.innerWidth,
    );
    expect(overflow).toBeLessThanOrEqual(2);
  });
});
