-- 1. Rename the existing "prices" table to "price_history" to safely keep existing data and UUIDs
ALTER TABLE public.prices RENAME TO price_history;

-- rename legacy indexes to reflect the new table name
ALTER INDEX IF EXISTS idx_prices_date RENAME TO idx_price_history_date;
ALTER INDEX IF EXISTS idx_prices_category RENAME TO idx_price_history_category;

-- 2. Drop the original primary key / unique constraint on item_eng that prevented historical entries
ALTER TABLE public.price_history DROP CONSTRAINT IF EXISTS prices_item_eng_key;

-- 3. Add a unique constraint on (item_eng, date) to allow idempotent scrape retries
ALTER TABLE public.price_history ADD CONSTRAINT price_history_item_eng_date_key UNIQUE (item_eng, date);

-- 4. Add an index for quick retrieval of the latest data via the view
CREATE INDEX IF NOT EXISTS idx_price_history_item_date ON public.price_history (item_eng, date DESC);

-- 5. Create the view "prices_latest" which the Flutter app will query
CREATE OR REPLACE VIEW public.prices_latest AS
    SELECT DISTINCT ON (item_eng) * 
    FROM public.price_history 
    ORDER BY item_eng, date DESC;
