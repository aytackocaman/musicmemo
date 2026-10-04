-- ============================================================================
-- Music Memo — Security fix #1 (CRITICAL): entitlement self-grant
-- Date: 2026-10-04
-- Tracking: zz_notes_credentials/security-audit.md (finding #1)
--
-- PROBLEM
--   public.subscriptions had INSERT and UPDATE policies scoped to the
--   caller's own row (auth.uid() = user_id), but with no restriction on the
--   column values: plan, status and expires_at were entirely caller-supplied.
--
--   The client treats that table as an entitlement authority — it asks
--   RevenueCat first and, on "not premium", falls through to this row. So any
--   authenticated user could PATCH their own row to plan='yearly' with a far
--   future expiry and unlock permanent premium, online multiplayer and every
--   daily limit. The 7-day trial was equally forgeable. The exploit worked
--   even while RevenueCat was live and correctly reporting "not premium".
--
-- FIX
--   The cache becomes server-write-only. RevenueCat (through a webhook using
--   service_role) is the only writer. Clients may only read their own row.
--
--   Companion client change (same commit): PurchaseService no longer mirrors
--   state into this table, and subscriptionProvider fails closed instead of
--   falling back to a cached row to grant premium.
--
--   ROLLBACK
--   Re-add the two permissive policies. Only do this together with removing
--   the client-side fallback, or the vulnerability returns.
-- ============================================================================

-- ─── Policies ───────────────────────────────────────────────────────────────

drop policy if exists "Users can insert own subscription" on public.subscriptions;
drop policy if exists "Users can update own subscription" on public.subscriptions;
drop policy if exists "Users can view own subscription"  on public.subscriptions;

create policy "Users can view own subscription"
  on public.subscriptions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- ─── Grants ─────────────────────────────────────────────────────────────────
-- Defence in depth: RLS above is the real control, but drop the table-level
-- privileges too so a future policy mistake cannot re-open write access.
-- service_role is intentionally untouched so the webhook can still write.

revoke all on public.subscriptions from anon;

revoke insert, update, delete on public.subscriptions from authenticated;
