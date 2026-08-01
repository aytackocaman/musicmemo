-- Allow client-side RevenueCat → Supabase subscription sync.
--
-- The app upserts the real plan + expires_at into `subscriptions`
-- after purchase/restore/login (see PurchaseService._syncToSupabase).
-- The original schema only granted SELECT, which blocks the upsert.

-- Users can insert their own subscription row (upsert fallback when
-- the handle_new_user trigger row is missing).
DROP POLICY IF EXISTS "Users can insert own subscription" ON subscriptions;
CREATE POLICY "Users can insert own subscription" ON subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update only their own subscription row.
DROP POLICY IF EXISTS "Users can update own subscription" ON subscriptions;
CREATE POLICY "Users can update own subscription" ON subscriptions
  FOR UPDATE USING (auth.uid() = user_id);
