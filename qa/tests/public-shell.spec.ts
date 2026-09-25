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
