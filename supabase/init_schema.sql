-- ============================================
-- KoyamRate – Consolidated Master Schema
-- ============================================

-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Prices table (core data)
CREATE TABLE IF NOT EXISTS public.prices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  item_tamil TEXT NOT NULL,
  item_eng TEXT NOT NULL UNIQUE,
  min_price NUMERIC(10,2) NOT NULL,
  max_price NUMERIC(10,2) NOT NULL,
  category TEXT DEFAULT 'vegetables',
  image_url TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Favorites table (sync across devices)
CREATE TABLE IF NOT EXISTS public.favorites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  item_id UUID REFERENCES public.prices(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, item_id)
);

-- 4. Price Alerts Table
CREATE TABLE IF NOT EXISTS public.price_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL,
    item_name_eng TEXT NOT NULL,
    item_name_tamil TEXT NOT NULL,
    min_price NUMERIC,
    max_price NUMERIC,
    notify_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, item_id)
);

-- 5. Notifications Queue Table (The "No-Firebase" Bridge)
CREATE TABLE IF NOT EXISTS public.notifications_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'price_alert',
    item_id TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Enable Row Level Security (RLS)
ALTER TABLE public.prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications_queue ENABLE ROW LEVEL SECURITY;

-- 7. RLS Policies

-- Public read prices
DROP POLICY IF EXISTS "Public read prices" ON public.prices;
CREATE POLICY "Public read prices" ON public.prices
  FOR SELECT USING (true);

-- Admin write prices (service role only)
DROP POLICY IF EXISTS "Admin write prices" ON public.prices;
CREATE POLICY "Admin write prices" ON public.prices
  FOR ALL USING (auth.role() = 'service_role');

-- Users manage own favorites
DROP POLICY IF EXISTS "Users manage own favorites" ON public.favorites;
CREATE POLICY "Users manage own favorites" ON public.favorites
  FOR ALL USING (auth.uid() = user_id);

-- Users manage own alerts
DROP POLICY IF EXISTS "Users manage own alerts" ON public.price_alerts;
CREATE POLICY "Users manage own alerts" ON public.price_alerts
    FOR ALL USING (auth.uid() = user_id);

-- Users manage own notification queue
DROP POLICY IF EXISTS "Users manage own notification queue" ON public.notifications_queue;
CREATE POLICY "Users manage own notification queue" ON public.notifications_queue
    FOR ALL USING (auth.uid() = user_id);

-- 8. Realtime Subscriptions
-- Wrap in a block to avoid error if already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'notifications_queue'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications_queue;
    END IF;
END $$;

-- 9. Account Deletion RPC (Privacy Compliance)
-- Allows a user to delete their OWN account from within the app.
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Re-verify that the user is deleting their own record
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

-- 10. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_prices_date ON public.prices(date DESC);
CREATE INDEX IF NOT EXISTS idx_prices_category ON public.prices(category);
