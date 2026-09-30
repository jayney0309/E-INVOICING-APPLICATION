# Setup Guide — Invoicing App

This is a multi-tenant invoicing web app: each of your clients (or your own
business) is a separate "business" with its own invoices, customers, and
settings, kept completely separate from every other business by database
rules — same pattern as the payroll apps built for you before (GitHub Pages
for hosting, Supabase for the login + database).

No coding or build step is required to deploy this — just the steps below.

## 1. Create your Supabase project

1. Go to supabase.com and sign in (or create a free account).
2. Click **New Project**. Pick any name and a database password (save the
   password somewhere safe — you likely won't need it again, but keep it).
3. Wait a minute or two for the project to finish setting up.

## 2. Load the database schema

1. In your new project, open the **SQL Editor** (left sidebar).
2. Click **New query**.
3. Open `sql/schema.sql` from this project, copy the whole file, paste it
   into the SQL Editor, and click **Run**.
4. You should see "Success. No rows returned." This created all the tables,
   security rules, and the invoice-numbering logic.

## 3. Get your API credentials

1. In Supabase, go to **Project Settings → API**.
2. Copy the **Project URL** and the **anon public** key.
3. Open `js/supabase-config.js` in this project and paste them in:
   ```js
   const SUPABASE_URL = "https://xxxxxxxx.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIs...";
   ```
   These two values are safe to be visible in the website's code — that's
   how Supabase is designed to work. The real protection is the database
   rules from step 2, which make sure one business can never see another
   business's data, no matter what.

## 4. (Recommended) Turn off email confirmation for faster testing

By default, Supabase asks new users to confirm their email before they can
sign in. While you're testing, you can turn this off:

1. **Authentication → Providers → Email** → turn off "Confirm email".
2. Turn it back on before real clients start signing up, so accounts are
   verified. (Or leave it off if you'll be creating each client's login
   yourself and handing it to them.)

## 5. Put it on GitHub Pages

1. Create a new GitHub repository (can be private).
2. Upload everything in this project **except** the `tests/` folder (that's
   only for you/a developer to re-run checks later — it needs a database
   to run and clients never need it).
3. In the repo, go to **Settings → Pages**, set the source to the branch
   you uploaded to (usually `main`) and the root folder, then save.
4. GitHub will give you a URL like `https://yourname.github.io/reponame/` —
   that's your live invoicing app.

## 6. First login

1. Open your GitHub Pages URL → click **Create one** to sign up with an
   email and password.
2. You'll land on a **Set up your business** screen — this is where you
   (or each client) enters their business name, TIN, address, VAT status,
   and invoice number prefix.
3. From there: add customers, create invoices, print or save them as PDF
   (the Print button uses your browser's built-in "Save as PDF").

## Giving a client their own account

Each client business should sign up with their own email/password at your
GitHub Pages URL and create their own business profile — their data is then
walled off from every other business automatically. If you want to be able
to see and help manage a client's invoices yourself, ask them to add your
email as a member of their business (a small "invite a teammate" feature
you can add later — for now this can be done directly in Supabase's Table
Editor under `business_members` by inserting a row with their
`business_id` and your `user_id`).

## What this app does and doesn't do yet

This covers your **own recordkeeping and client-facing invoices** —
sequential numbering, VAT/Non-VAT computation, printable/PDF invoices, and
a record of everything issued. It does **not** yet transmit anything to
BIR's Electronic Invoicing System (EIS) — see `docs/EIS_ROADMAP.md` for
exactly what that would take and when it becomes possible to add.

## Troubleshooting

- **Blank page / "connect your Supabase project" message** — you haven't
  filled in `js/supabase-config.js` yet (step 3).
- **"Invalid API key" or similar on login** — double check you copied the
  *anon public* key, not the *service_role* key (the service_role key
  should never go in this file — it bypasses all the security rules).
- **A client can see another client's data** — this should never happen
  given the security rules in `sql/schema.sql`; if you ever see it, stop
  and get in touch rather than continuing to use the app.
