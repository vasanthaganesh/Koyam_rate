/**
 * KoyamRate – Daily CMDA Koyambedu Price Scraper
 * ================================================
 * Fetches today's vegetable wholesale prices from the CMDA Chennai website,
 * normalizes the names to match the app's database/asset convention,
 * and inserts them into the Supabase 'price_history' table.
 *
 * Usage:
 *   node scraper/scrape_and_upsert.mjs              # scrape + insert to Supabase
 *   node scraper/scrape_and_upsert.mjs --dry-run    # scrape only, print to console
 */

import https from 'https';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'path';

// Load .env from the parent directory (project root)
dotenv.config({ path: path.resolve(process.cwd(), '../.env') });

// ── Config ──────────────────────────────────────────────────

const MMCKWMC_TOKEN_URL = 'https://api.mmckwmc.tn.gov.in/admin/generatetoken';
const MMCKWMC_PRICES_URL = 'https://api.mmckwmc.tn.gov.in/price/viewcategorybyid/4';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

// ── Name Normalization Map ────────────────────────────────────
// Maps CMDA website English names → KoyamRate app item_eng names.
// If a CMDA name is not in this map it is used as-is with Title Case.

const NAME_MAP = {
  'Tomato': 'Tomato Hybrid',
  'Tomato – Navin': 'Tomato Hybrid',
  'Tomato - Navin': 'Tomato Hybrid',
  'Sabre-Bean': 'Hyacinth Beans',
  'Ladies finger': 'Ladies Finger',
  'Beet root': 'Beetroot',
  'Bitter gourd': 'Bitter Gourd',
  'Snake-gourd': 'Snake Gourd',
  'Green Chillies': 'Green Chilli',
  'Onion - Sambar': 'Sambar Onion',
  'Green Plantain - Per Piece': 'Raw Banana',
  'Nookal': 'Kohlrabi',
  'Cauliflower – Per Piece': 'Cauliflower',
  'Cauliflower - Per Piece': 'Cauliflower',
  'Little Gourd': 'Scarlet Gourd',
  'Mango': 'Mango Raw',
  'Coconut - per piece': 'Coconut',
  'Coriander - 50 Bundles': 'Coriander Leaves',
};

// Tamil name overrides (when CMDA Tamil names differ from app convention)
const TAMIL_MAP = {
  'Bangalore Tomato': 'பெங்களூர் தக்காளி',
  'Tomato Hybrid': 'தக்காளி நவின்',
  'Hyacinth Beans': 'அவரைக்காய்',
  'Ladies Finger': 'வெண்டைக்காய்',
  'Beetroot': 'பீட்ரூட்',
  'Bitter Gourd': 'பாகற்காய்',
  'Snake Gourd': 'புடலங்காய்',
  'Green Chilli': 'பச்சை மிளகாய்',
  'Sambar Onion': 'சின்ன வெங்காயம்',
  'Raw Banana': 'வாழைக்காய்',
  'Kohlrabi': 'நூக்கல்',
  'Cauliflower': 'காலிஃபிளவர்',
  'Scarlet Gourd': 'கோவைக்காய்',
  'Mango Raw': 'மாங்காய்',
  'Coconut': 'தேங்காய்',
  'Coriander Leaves': 'கொத்தமல்லிக்கட்டு',
  'Elephant Yam': 'சேனைக் கிழங்கு',
  'Onion': 'பெரிய வெங்காயம்',
};

// ── Helpers ─────────────────────────────────────────────────

/**
 * Get today's date in IST as YYYY-MM-DD
 */
function getTodayIST() {
  const now = new Date();
  // IST is UTC+5:30
  const istOffset = 5.5 * 60 * 60 * 1000;
  const ist = new Date(now.getTime() + istOffset + now.getTimezoneOffset() * 60 * 1000);
  const y = ist.getFullYear();
  const m = String(ist.getMonth() + 1).padStart(2, '0');
  const d = String(ist.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Normalize an English item name from API to app convention.
 */
function normalizeEngName(raw) {
  // Try exact match first
  if (NAME_MAP[raw]) return NAME_MAP[raw];
  // Try partial match
  for (const [key, value] of Object.entries(NAME_MAP)) {
    if (raw.startsWith(key)) return value;
  }
  // Title Case the raw name as fallback
  return raw.replace(/\b\w/g, c => c.toUpperCase());
}

async function fetchWithRetry(url, options = {}, retries = 3, backoff = 2000) {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(url, options);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res;
    } catch (err) {
      const isLast = i === retries - 1;
      console.warn(`⚠️ Fetch failed (Attempt ${i + 1}/${retries}): ${err.message}`);
      if (isLast) throw err;
      console.log(`⏳ Retrying in ${backoff / 1000}s...`);
      await new Promise(r => setTimeout(r, backoff));
      backoff *= 2;
    }
  }
}

async function fetchPricesJson() {
  console.log('🔑 Generating MMC KWMC API Token...');
  const tokenRes = await fetchWithRetry(MMCKWMC_TOKEN_URL);
  const tokenData = await tokenRes.json();
  const token = tokenData.response;

  console.log('🔄 Fetching JSON prices from MMC KWMC...');
  const res = await fetchWithRetry(MMCKWMC_PRICES_URL, {
    headers: {
      'x_access_token': `Bearer ${token}`,
      'Origin': 'https://mmckwmc.tn.gov.in'
    }
  });
  const data = await res.json();
  return data.response;
}

async function scrapeMarketData() {
  const jsonRows = await fetchPricesJson();

  if (!jsonRows || jsonRows.length === 0) {
    throw new Error('Parsing returned 0 rows – MMC KWMC API may have changed!');
  }

  const results = [];
  const today = getTodayIST();

  for (const item of jsonRows) {
    const item_eng_raw = item.nameInEnglish;
    const item_tamil_raw = item.nameInTamil;
    const min_price = parseFloat(item.minPrice);
    const max_price = parseFloat(item.maxPrice);

    if (isNaN(min_price) || isNaN(max_price)) continue;

    // Normalize names
    const item_eng = normalizeEngName(item_eng_raw);
    // Use Tamil override if available, otherwise keep the parsed Tamil
    const final_tamil = TAMIL_MAP[item_eng] || item_tamil_raw || item_eng;

    results.push({
      date: today,
      item_eng,
      item_tamil: final_tamil,
      min_price,
      max_price,
      category: 'vegetables',
    });
  }

  console.log(`✅ Scraped ${results.length} vegetables from new MMC KWMC API`);
  return results;
}

// ── Supabase Upsert ─────────────────────────────────────────

async function upsertToSupabase(rows) {
  const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

  // // Changed to appending to match new insert pattern
  console.log(`📤 Appending ${rows.length} rows to price_history table...`);

  // // Changed target table to 'price_history', added onConflict 'item_eng,date' and used ignoreDuplicates
  // // Added select() to get actually inserted rows to log duplicate skips
  const { data, error } = await supabase
    .from('price_history')
    .upsert(rows, {
      onConflict: 'item_eng,date',
      ignoreDuplicates: true,
    })
    .select();

  if (error) {
    throw new Error(`Supabase insert failed: ${error.message}`);
  }

  // // Log actual inserted vs skipped based on response
  const insertedCount = data ? data.length : 0;
  const skippedCount = rows.length - insertedCount;
  const today = rows[0]?.date || 'unknown';
  
  console.log(`✅ Completed database operation for ${today}`);
  console.log(`   - Total Scraped: ${rows.length}`);
  console.log(`   - Inserted New:  ${insertedCount}`);
  console.log(`   - Skipped Exists:${skippedCount}`);
  
  return data;
}

// ── Main ────────────────────────────────────────────────────

async function main() {
  const dryRun = process.argv.includes('--dry-run');

  try {
    const rows = await scrapeMarketData();

    if (dryRun) {
      console.log('\n🧪 DRY RUN – printing all scraped rows:\n');
      console.log(JSON.stringify(rows, null, 2));
      console.log(`\nTotal: ${rows.length} rows for date: ${rows[0]?.date}`);
      return;
    }

    await upsertToSupabase(rows);
    console.log(`\n🎉 Daily scraper completed at ${new Date().toISOString()}`);

    // Small delay to ensure all async handles are closed before exit
    setTimeout(() => process.exit(0), 100);

  } catch (err) {
    console.error('❌ SCRAPER ERROR:', err.message);
    setTimeout(() => process.exit(1), 100);
  }
}

main();
