# Invoicing App

A multi-tenant invoicing web app: each business (yours or a client's) gets
its own login, customers, and sequentially-numbered VAT/Non-VAT invoices,
kept fully separate from every other business.

**Start here → [`SETUP.md`](SETUP.md)** for deployment steps (Supabase +
GitHub Pages, no coding required).

**Where this stands on BIR e-invoicing (EIS) →
[`docs/EIS_ROADMAP.md`](docs/EIS_ROADMAP.md)** — what's built now, and
exactly what's blocked on a per-business Permit to Issue and BIR portal
access.

## Project layout

```
index.html          Sign in / sign up
app.html             Dashboard — business setup, summary, recent invoices
new-invoice.html     Create an invoice
invoice.html         View / print / void / export an invoice
customers.html       Manage saved customers
settings.html        Business profile (name, TIN, VAT status, numbering)
css/style.css        All styling
js/db.js             Supabase data access (the only file that talks to the DB)
js/nav.js            Shared top bar + business switcher
js/util.js           Formatting, tax-preview math, EIS-draft JSON export
js/supabase-config.js  Your Supabase credentials go here (see SETUP.md)
sql/schema.sql       Database tables, security rules, invoice-numbering logic
tests/               Automated checks for the database logic (optional, for
                      you or a developer to re-run later — not needed to use
                      the app day to day)
```

## Tech notes

- Plain HTML/CSS/JavaScript — no build step, no framework. Edit and
  re-upload to GitHub, that's it.
- Supabase (Postgres + Auth) handles logins and storage. Row Level
  Security policies in `sql/schema.sql` are what actually keep each
  business's data private — not anything in the app code.
- Invoice numbering and VAT math are computed by a database function
  (`fn_create_invoice`), not in the browser, so two people issuing
  invoices for the same business at the same moment can never collide on
  the same invoice number.
