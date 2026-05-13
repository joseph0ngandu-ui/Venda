import { expect, test } from '@playwright/test';

test('renders installable Venda shell and manifest metadata', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByRole('heading', { name: 'venda' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Set up my business' })).toBeVisible();

  const manifest = await page.evaluate(async () => {
    const response = await fetch('/manifest.webmanifest');
    return response.json();
  });

  expect(manifest.name).toBe('Venda');
  expect(manifest.display).toBe('standalone');
});
