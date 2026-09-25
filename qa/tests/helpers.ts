import { expect, Page, TestInfo } from '@playwright/test';

export async function openFolego(page: Page) {
  const pageErrors: string[] = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));

  await page.goto('./', { waitUntil: 'domcontentloaded' });
  await page.locator('flutter-view').waitFor({ state: 'attached', timeout: 30_000 });
  await expect(page).toHaveTitle(/Fôlego/i);
  await page.waitForTimeout(1_000);

  return pageErrors;
}

export async function enableFlutterAccessibility(page: Page) {
  const button = page.getByRole('button', { name: /enable accessibility/i });
  if (await button.count()) {
    await button.first().click();
    await page.waitForTimeout(250);
  }
}

export async function capture(page: Page, testInfo: TestInfo, name: string) {
  await page.screenshot({
    path: testInfo.outputPath(`${name}.png`),
    fullPage: true,
    animations: 'disabled',
  });
}
