const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer');

const ROOT = path.resolve(__dirname, '../..');
const OUT_DIR = path.join(ROOT, 'assets', 'map');
const OUT_PNG = path.join(OUT_DIR, 'base_ohm.png');
const OUT_JSON = path.join(OUT_DIR, 'base_ohm.json');
const HTML = path.join(__dirname, 'export.html');

const VIEWPORT_W = 4096;
const VIEWPORT_H = 3240;
const TIMEOUT_MS = 120000;

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: VIEWPORT_W, height: VIEWPORT_H, deviceScaleFactor: 1 });
    const fileUrl = 'file:///' + HTML.replace(/\\/g, '/');
    console.log('[ohm_export] loading', fileUrl);
    await page.goto(fileUrl, { waitUntil: 'networkidle0', timeout: TIMEOUT_MS });
    await page.waitForFunction(
      () => window.__OHM_EXPORT__ && window.__OHM_EXPORT__.ready === true,
      { timeout: TIMEOUT_MS }
    );

    const meta = await page.evaluate(() => window.__OHM_EXPORT__);
    await page.screenshot({ path: OUT_PNG, type: 'png', fullPage: false });
    fs.writeFileSync(OUT_JSON, JSON.stringify({
      source: 'OpenHistoricalMap',
      style: 'https://www.openhistoricalmap.org/map-styles/main/main.json',
      filterDate: meta.filterDate,
      bbox: meta.bbox,
      width: meta.width,
      height: meta.height,
      attribution: '© OpenHistoricalMap contributors',
      note: 'OHM tiles are filtered by date in MapLibre before raster export. Game markers are projected onto this bbox with Web Mercator.'
    }, null, 2), 'utf8');

    console.log('[ohm_export] saved', OUT_PNG);
    console.log('[ohm_export] saved', OUT_JSON);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('[ohm_export] FAILED:', err);
  process.exit(1);
});
