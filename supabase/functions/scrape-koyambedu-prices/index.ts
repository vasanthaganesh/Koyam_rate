/**
 * KoyamRate – Supabase Edge Function: scrape-koyambedu-prices
 * ============================================================
 * Deno-based Edge Function that can be invoked manually or via
 * Supabase pg_cron / external scheduler (GitHub Actions, etc).
 *
 * Deploy:
 *   supabase functions deploy scrape-koyambedu-prices --no-verify-jwt
 *
 * Invoke manually:
 *   curl -X POST https://ivhezxezaunyohypmswd.supabase.co/functions/v1/scrape-koyambedu-prices \
 *     -H "Authorization: Bearer <ANON_KEY>"
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ── Name normalization from CMDA → App convention ──

const NAME_MAP: Record<string, string> = {
  'Tomato':                     'Tomato Hybrid',
  'Tomato – Navin':             'Tomato Hybrid',
  'Tomato - Navin':             'Tomato Hybrid',
  'Sabre-Bean':                 'Hyacinth Beans',
  'Ladies finger':              'Ladies Finger',
  'Beet root':                  'Beetroot',
  'Bitter gourd':               'Bitter Gourd',
  'Snake-gourd':                'Snake Gourd',
  'Green Chillies':             'Green Chilli',
  'Onion - Sambar':             'Sambar Onion',
  'Green Plantain - Per Piece': 'Raw Banana',
  'Nookal':                     'Kohlrabi',
  'Cauliflower – Per Piece':    'Cauliflower',
  'Cauliflower - Per Piece':    'Cauliflower',
  'Little Gourd':               'Scarlet Gourd',
  'Mango':                      'Mango Raw',
  'Coconut - per piece':        'Coconut',
  'Coriander - 50 Bundles':     'Coriander Leaves',
};

const TAMIL_MAP: Record<string, string> = {
  'Bangalore Tomato': 'பெங்களூர் தக்காளி',
  'Tomato Hybrid':    'தக்காளி நவின்',
  'Hyacinth Beans':   'அவரைக்காய்',
  'Ladies Finger':    'வெண்டைக்காய்',
  'Beetroot':         'பீட்ரூட்',
  'Bitter Gourd':     'பாகற்காய்',
  'Snake Gourd':      'புடலங்காய்',
  'Green Chilli':     'பச்சை மிளகாய்',
  'Sambar Onion':     'சின்ன வெங்காயம்',
  'Raw Banana':       'வாழைக்காய்',
  'Kohlrabi':         'நூக்கல்',
  'Cauliflower':      'காலிஃபிளவர்',
  'Scarlet Gourd':    'கோவைக்காய்',
  'Mango Raw':        'மாங்காய்',
  'Coconut':          'தேங்காய்',
  'Coriander Leaves': 'கொத்தமல்லிக்கட்டு',
  'Elephant Yam':     'சேனைக் கிழங்கு',
  'Onion':            'பெரிய வெங்காயம்',
};

function normalizeEngName(raw: string): string {
  if (NAME_MAP[raw]) return NAME_MAP[raw];
  for (const [key, value] of Object.entries(NAME_MAP)) {
    if (raw.startsWith(key)) return value;
  }
  return raw.replace(/\b\w/g, (c) => c.toUpperCase());
}

function getTodayIST(): string {
  const now = new Date();
  const istOffset = 5.5 * 60 * 60 * 1000;
  const ist = new Date(now.getTime() + istOffset + now.getTimezoneOffset() * 60 * 1000);
  const y = ist.getFullYear();
  const m = String(ist.getMonth() + 1).padStart(2, '0');
  const d = String(ist.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

interface ScrapedRow {
  date: string;
  item_eng: string;
  item_tamil: string;
  min_price: number;
  max_price: number;
  category: string;
}

const MMCKWMC_TOKEN_URL = 'https://api.mmckwmc.tn.gov.in/admin/generatetoken';
const MMCKWMC_PRICES_URL = 'https://api.mmckwmc.tn.gov.in/price/viewcategorybyid/4';

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

async function fetchWithRetry(url: string, options: RequestInit = {}, retries = 3, backoff = 2000, timeoutMs = 30000): Promise<Response> {
  const headers = {
    'User-Agent': USER_AGENT,
    ...(options.headers || {}),
  };

  for (let i = 0; i < retries; i++) {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), timeoutMs);

    try {
      console.log(`🌐 Fetching: ${url} (Attempt ${i + 1}/${retries})...`);
      const res = await fetch(url, {
        ...options,
        headers,
        signal: controller.signal,
      });
      clearTimeout(id);

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}: ${res.statusText}`);
      }
      return res;
    } catch (err) {
      clearTimeout(id);
      const isLast = i === retries - 1;
      const errorName = err instanceof Error ? err.name : 'UnknownError';
      const errorMessage = err instanceof Error ? err.message : String(err);
      
      let finalMessage = errorMessage;
      if (errorName === 'AbortError') {
        finalMessage = `Request timed out after ${timeoutMs / 1000}s`;
      }

      console.warn(`⚠️ Fetch failed (${url}): ${finalMessage}`);
      
      if (isLast) {
        throw new Error(`Failed to fetch ${url} after ${retries} attempts. Last error: ${finalMessage}`);
      }
      
      console.log(`⏳ Retrying in ${backoff / 1000}s...`);
      await new Promise(r => setTimeout(r, backoff));
      backoff *= 2;
    }
  }
  throw new Error('Unreachable');
}

async function fetchPricesJson(): Promise<any[]> {
  console.log('🔑 Generating MMC KWMC API Token...');
  const tokenRes = await fetchWithRetry(MMCKWMC_TOKEN_URL);
  const tokenData = await tokenRes.json();

  if (!tokenData?.response) {
    throw new Error(`Token API returned unexpected response: ${JSON.stringify(tokenData)}`);
  }
  const token = tokenData.response;

  console.log('🔄 Fetching JSON prices from MMC KWMC...');
  console.log(`📡 Using token preview: ${token.substring(0, 15)}...`);
  
  const res = await fetchWithRetry(MMCKWMC_PRICES_URL, {
    headers: {
      'x_access_token': `Bearer ${token}`,
      'Origin': 'https://mmckwmc.tn.gov.in'
    }
  });
  const data = await res.json();
  
  if (data?.response) {
    console.log(`📊 API returned ${data.response.length} rows.`);
  } else {
    console.warn('⚠️ API returned no data in "response" field:', JSON.stringify(data));
  }
  
  return data.response;
}

async function scrapeMarketData(): Promise<ScrapedRow[]> {
  const jsonRows = await fetchPricesJson();

  if (!jsonRows || jsonRows.length === 0) {
    throw new Error('Parsing returned 0 rows – API structure may have changed!');
  }

  const results: ScrapedRow[] = [];
  const today = getTodayIST();

  for (const item of jsonRows) {
    const item_eng_raw = item.nameInEnglish;
    const item_tamil_raw = item.nameInTamil;
    const min_price = parseFloat(item.minPrice);
    const max_price = parseFloat(item.maxPrice);

    if (isNaN(min_price) || isNaN(max_price)) continue;

    const item_eng = normalizeEngName(item_eng_raw);
    const item_tamil = TAMIL_MAP[item_eng] || item_tamil_raw || item_eng;

    results.push({ date: today, item_eng, item_tamil, min_price, max_price, category: 'vegetables' });
  }

  return results;
}

Deno.serve(async (_req) => {
  try {
    // Auth: require a secret header for invocations
    const scraperSecret = Deno.env.get('SCRAPER_SECRET');
    if (scraperSecret) {
      const authHeader = _req.headers.get('x-scraper-secret');
      if (authHeader !== scraperSecret) {
        return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        });
      }
    }

    const rows = await scrapeMarketData();

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { error } = await supabase
      .from('prices')
      .upsert(rows, { onConflict: 'item_eng', ignoreDuplicates: false });

    if (error) {
      console.error('Supabase upsert error:', error.message);
      return new Response(JSON.stringify({ success: false, error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const msg = `Scraped ${rows.length} vegetables successfully on ${rows[0]?.date}`;
    console.log(`✅ ${msg}`);

    return new Response(JSON.stringify({ success: true, message: msg, count: rows.length }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('❌ Scraper error:', message);
    return new Response(JSON.stringify({ success: false, error: message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
