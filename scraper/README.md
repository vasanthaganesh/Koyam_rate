# KoyamRate – Daily Price Scraper

Scrapes daily wholesale vegetable prices from the **CMDA Koyambedu Market** website and upserts them into the Supabase `prices` table.

**Source:** [cmdachennai.gov.in/CommodityRate/CommodityRateToday.aspx](https://www.cmdachennai.gov.in/CommodityRate/CommodityRateToday.aspx)

---

## Setup (One Time)

### 1. Add Unique Constraint to Supabase

Run the following SQL in your **Supabase SQL Editor** (Dashboard → SQL):

```sql
ALTER TABLE prices
  ADD CONSTRAINT prices_date_item_eng_unique
  UNIQUE (date, item_eng);
```

This allows the scraper to upsert (update if exists, insert if new) based on `(date, item_eng)`.

### 2. Add Service Role Key to .env

The scraper needs bypass-level permissions to write to the `prices` table (due to RLS).

1. Go to your **Supabase Dashboard** → **Settings** → **API**.
2. Find the **service_role / secret** key (click "reveal").
3. Add it to your `.env` file (at the project root):
   ```env
   SUPABASE_SERVICE_ROLE_KEY=your_secret_key_here
   ```

### 3. Install Dependencies (Local Scraper)

```bash
cd scraper
npm install
```

---

## Running the Scraper

### Dry Run (Test Only – No DB Write)

```bash
cd scraper
npm run scrape:dry
# or
node scrape_and_upsert.mjs --dry-run
```

This fetches from CMDA, normalizes names, and prints all 32 rows to console.

### Live Run (Scrape + Upsert to Supabase)

```bash
cd scraper
npm run scrape
# or
node scrape_and_upsert.mjs
```

---

## Production Deployment Options

### Option A: Supabase Edge Function (Recommended)

1. Install Supabase CLI if not installed:
   ```bash
   npm install -g supabase
   ```

2. Link your project:
   ```bash
   supabase login
   supabase link --project-ref ivhezxezaunyohypmswd
   ```

3. Deploy the function:
   ```bash
   supabase functions deploy scrape-koyambedu-prices --no-verify-jwt
   ```

4. Invoke manually:
   ```bash
   curl -X POST https://ivhezxezaunyohypmswd.supabase.co/functions/v1/scrape-koyambedu-prices \
     -H "Authorization: Bearer YOUR_ANON_KEY"
   ```

5. Schedule daily at 9:00 AM IST (3:30 AM UTC) using **pg_cron** in SQL Editor:
   ```sql
   SELECT cron.schedule(
     'daily-price-scrape',
     '30 3 * * *',   -- 3:30 AM UTC = 9:00 AM IST
     $$
     SELECT net.http_post(
       url := 'https://ivhezxezaunyohypmswd.supabase.co/functions/v1/scrape-koyambedu-prices',
       headers := '{"Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
     );
     $$
   );
   ```

### Option B: GitHub Actions (Free Cron)

Create `.github/workflows/scrape.yml`:

```yaml
name: Daily Price Scrape
on:
  schedule:
    - cron: '30 3 * * *'  # 3:30 AM UTC = 9:00 AM IST
  workflow_dispatch:       # allow manual trigger

jobs:
  scrape:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: cd koyam_rate/scraper && npm install
      - run: cd koyam_rate/scraper && node scrape_and_upsert.mjs
```

### Option C: Windows Task Scheduler (Local)

1. Open Task Scheduler
2. Create Basic Task → "KoyamRate Price Scrape"
3. Trigger: Daily at 9:00 AM
4. Action: Start a program
   - Program: `node`
   - Arguments: `scrape_and_upsert.mjs`
   - Start in: `C:\...\koyam_rate\scraper`

---

## Checking Logs

- **Edge Function logs:** Supabase Dashboard → Functions → scrape-koyambedu-prices → Logs
- **GitHub Actions logs:** GitHub repo → Actions tab → Daily Price Scrape
- **Local logs:** Console output shows `✅ Scraped X vegetables successfully on [date]`

---

## Name Normalization

The CMDA site uses different names than the app. The scraper normalizes them automatically:

| CMDA Site Name | App Name (item_eng) |
|---|---|
| Tomato | Bangalore Tomato |
| Tomato – Navin | Tomato Hybrid |
| Sabre-Bean | Hyacinth Beans |
| Ladies finger | Ladies Finger |
| Beet root | Beetroot |
| Green Chillies | Green Chilli |
| Onion - Sambar | Sambar Onion |
| Nookal | Kohlrabi |
| Little Gourd | Scarlet Gourd |
| Mango | Mango Raw |

---

## Troubleshooting

- **"Supabase upsert failed"** → Check that the unique constraint exists (`prices_date_item_eng_unique`)
- **"No table rows found"** → CMDA site may be down or structure changed
- **0 rows parsed** → CMDA changed HTML layout; inspect the page and update the regex
