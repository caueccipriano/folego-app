import { expect, test } from '@playwright/test';
import { capture, openFolego } from './helpers';

test.describe('Fôlego public PWA shell', () => {
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
    expect(manifestHref).toBeTruthy();

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
    expect(appleIconHref).toBe('apple-touch-icon.png');

    // iOS doesn't reliably use the manifest. A missing, blank, or invalid PNG
    // can silently create a generic home-screen bookmark despite valid tags.
    const appleIconUrl = new URL(appleIconHref!, baseURL!).toString();
    const iconResponse = await request.get(appleIconUrl);
    expect(iconResponse.ok()).toBeTruthy();
    expect(iconResponse.headers()['content-type']).toContain('image/png');
    const iconPng = await iconResponse.body();
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
      (icon: { src: string }) => icon.src === 'apple-touch-icon.png',
    );
    expect(manifestAppleIcon?.sizes).toBe('180x180');
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
