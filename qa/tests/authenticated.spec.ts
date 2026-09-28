import { expect, test } from '@playwright/test';
import { capture, enableFlutterAccessibility, openFolego } from './helpers';

const email = process.env.FOLEGO_E2E_EMAIL;
const password = process.env.FOLEGO_E2E_PASSWORD;

test.describe('authenticated navigation smoke', () => {
  test.skip(!email || !password, 'FOLEGO_E2E_EMAIL / FOLEGO_E2E_PASSWORD not configured');

  test('logs in and navigates through the five main destinations', async ({
    page,
  }, testInfo) => {
    const pageErrors = await openFolego(page);
    await enableFlutterAccessibility(page);

    const emailField = page.getByRole('textbox', { name: /e-mail/i }).first();
    await expect(emailField).toBeVisible();
    await emailField.fill(email!);

    const passwordField = page
      .getByRole('textbox', { name: /senha/i })
      .first();
    await expect(passwordField).toBeVisible();
    await passwordField.fill(password!);

    await page.getByRole('button', { name: /^entrar$/i }).click();

    const destinations = ['início', 'lançamentos', 'plano', 'carteira', 'perfil'];
    await expect(page.getByText('início', { exact: true }).first()).toBeVisible({
      timeout: 30_000,
    });

    for (const destination of destinations) {
      const target = page.getByText(destination, { exact: true }).first();
      await target.click();
      await page.waitForTimeout(350);
      await expect(page.locator('flutter-view')).toBeVisible();
      const geometry = await page.evaluate(() => ({
        viewportWidth: window.innerWidth,
        documentWidth: document.documentElement.scrollWidth,
      }));
      expect.soft(
        geometry.documentWidth,
        `Horizontal overflow on ${destination} (${testInfo.project.name})`,
      ).toBeLessThanOrEqual(geometry.viewportWidth + 2);
      await capture(page, testInfo, `auth-${destination}`);
    }
    expect.soft(pageErrors, pageErrors.join('\n')).toEqual([]);
  });
});
