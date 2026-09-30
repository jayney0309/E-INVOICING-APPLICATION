// ============================================================================
// FILL THIS IN AFTER YOU CREATE YOUR SUPABASE PROJECT.
// Supabase dashboard > Project Settings > API > "Project URL" and
// "anon public" key. These two values are safe to expose in client-side
// code — that is how Supabase is designed to work; real security comes
// from the Row Level Security policies in sql/schema.sql, not from
// hiding this key.
// ============================================================================
const SUPABASE_URL = "https://gikvscsmevmkpxiniwyu.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_yG_egTkPFzCfcyYlc_FexA_Hu1RZ72Z";

let supabaseClient;
if (SUPABASE_URL.startsWith("YOUR_") || SUPABASE_ANON_KEY.startsWith("YOUR_")) {
  // Friendly guard so an unconfigured deploy shows a clear message instead
  // of a blank page. Once you fill in real values above, this never runs.
  document.addEventListener("DOMContentLoaded", () => {
    document.body.innerHTML = `
      <div style="max-width:520px;margin:80px auto;padding:24px;font-family:-apple-system,Arial,sans-serif;background:#fff8e1;border:1px solid #f0d98c;border-radius:10px;color:#6b5900;">
        <h2 style="margin-top:0;">Almost there — connect your Supabase project</h2>
        <p>Open <code>js/supabase-config.js</code> and paste in your Supabase Project URL and anon key (Supabase dashboard &rarr; Project Settings &rarr; API).</p>
        <p>See <code>SETUP.md</code> in this project for the full step-by-step walkthrough.</p>
      </div>`;
  });
} else {
  supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}
