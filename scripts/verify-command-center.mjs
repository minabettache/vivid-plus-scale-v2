const baseUrl = process.env.VIVID_BASE_URL ?? 'http://localhost:3000';

async function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function verifyPage() {
  const response = await fetch(`${baseUrl}/`, { redirect: 'follow' });
  const html = await response.text();

  await assert(response.ok, `Home page returned ${response.status}`);
  await assert(response.url.includes('/command-center'), 'Home page did not redirect to /command-center');
  await assert(html.includes('Executive Command Center'), 'Command Center UI was not found in the HTML');

  console.log('PASS  Home opens the Executive Command Center');
}

async function verifyApi() {
  const response = await fetch(`${baseUrl}/api/v1/command-center?period=today`, {
    headers: { 'x-vivid-organization-id': 'vivid-technologies' }
  });

  await assert(response.ok, `Command Center API returned ${response.status}`);

  const payload = await response.json();
  const snapshot = payload?.data;

  await assert(snapshot, 'API response is missing data');
  await assert(typeof snapshot.health?.score === 'number', 'API response is missing the health score');
  await assert(Array.isArray(snapshot.metrics), 'API response is missing metrics');
  await assert(Array.isArray(snapshot.priorities), 'API response is missing priorities');
  await assert(Array.isArray(snapshot.salesSeries), 'API response is missing salesSeries');

  console.log('PASS  Command Center API contract is valid');
}

try {
  await verifyPage();
  await verifyApi();
  console.log('\nVIVID+ verification complete. Everything is working.');
} catch (error) {
  console.error('\nVIVID+ verification failed.');
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
}
