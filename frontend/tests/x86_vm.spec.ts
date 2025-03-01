import { test, expect, type Page } from '../playwright/fixtures';
import { clearState, deleteAllTasks } from './utils';
import * as os from 'os';

test.skip(os.arch() !== 'x64', 'You can only run this suite in an x86 VM');

const colorSchemes = ['light', 'dark'] as const;

const createConfiguration = async (
	page: Page,
	name: string,
	deviceType: string,
	tags: string[]
) => {
	await page.goto('/configuration/list');

	const addConfigurationButton = page
		.locator('button')
		.filter({ hasText: 'Create New Configuration' });
	await addConfigurationButton.click();

	const displayNameInput = page.locator('#display-name').first();
	await displayNameInput.fill(name);

	const deviceTypeSelect = page.locator('#device-type').first();
	await deviceTypeSelect.selectOption({ label: deviceType });

	if (tags.length > 0) {
		const tagsMultiSelect = page.locator('input[autocomplete]');
		await tagsMultiSelect.click();

		// for each tag, input and enter
		for (const tag of tags) {
			await page.getByRole('option', { name: tag }).click();
		}
	}

	await page.getByRole('heading', { name: 'Create a new device' }).click();

	const saveButton = page.locator('button').filter({ hasText: 'Create device configuration' });
	await saveButton.click();
};

colorSchemes.forEach((colorScheme) => {
	test.describe(`Color scheme: ${colorScheme}`, () => {
		test.use({ colorScheme: colorScheme });
		test('Create a x64 vm and run it', async ({ page, request }) => {
			await clearState(page, request);
			await deleteAllTasks(page, request);

			await createConfiguration(page, 'VM Test x64', 'Generic x86-64', []);

			await page.goto('/configuration/list');

			// find row with 'VM Test x64' and click on button 'View Details'
			await page
				.locator('tr')
				.filter({ hasText: 'VM Test x64' })
				.getByRole('button', { name: 'View Details' })
				.first()
				.click();

			// select button "Build and start VM"
			await page.locator('button').filter({ hasText: 'Build and start VM' }).first().click();

			// wait until: 1x on screen "completed", 1x on screen "running"
			test.setTimeout(300000);
			await page.locator('td', { hasText: 'completed' }).first().waitFor({ timeout: 300000 });
			await page.locator('td', { hasText: 'running' }).first().waitFor({ timeout: 30000 });

			// wait until "Deployed:" is shown on screen
			await page.locator('p', { hasText: 'Deployed:' }).first().waitFor({ timeout: 300000 });

			await expect(page).toHaveScreenshot({
				mask: [page.locator('.playwright-snapshot-unstable')]
			});
		});
	});
});
