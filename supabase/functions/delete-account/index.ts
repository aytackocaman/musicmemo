import { createClient } from "npm:@supabase/supabase-js@2";

// Deletes the calling user's account permanently.
//
// Security model:
//  * verify_jwt is ON — only authenticated users can reach this function
//  * the caller's own JWT is resolved to their user id (no user-supplied id)
//  * uses the service role key (never exposed to clients) to revoke
//    sessions and hard-delete the auth user; FK ON DELETE CASCADE then
//    removes the profile and all user-owned rows.
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const jwt = authHeader.slice(7);

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } },
  );

  // Resolve the caller from their JWT.
  const { data: { user }, error: userError } = await supabase.auth.getUser(jwt);
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Deleting a user does not invalidate existing access tokens — revoke
  // all of the user's sessions first.
  await supabase.auth.admin.signOut(jwt);

  // Hard delete the auth user; the profiles FK (ON DELETE CASCADE) and its
  // children remove all user-owned data (stats, games, counts, ...).
  const { error: deleteError } = await supabase.auth.admin.deleteUser(user.id);
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
