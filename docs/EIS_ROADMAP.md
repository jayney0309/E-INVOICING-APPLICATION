# Path to BIR e-invoicing (EIS) compliance

This explains, plainly, what this app already does toward BIR's Electronic
Invoicing System (EIS) requirement, and what genuinely cannot be built
until a specific business has gone through BIR's own process.

## What's built now

- Every invoice is created through one database function that computes
  VAT/Non-VAT amounts correctly and assigns a sequential invoice number —
  no two invoices for the same business can ever share a number, and past
  invoices never change if settings change later.
- Every invoice stores the fields BIR's e-invoicing format is known to
  need: seller details (name, TIN, branch code, address), buyer details,
  issue date, line items, gross/VAT/net amounts.
- Each invoice can be printed / saved as a PDF in a layout that satisfies
  ordinary BIR invoicing and recordkeeping rules (the "Invoice" document
  that replaced separate Sales Invoices/Official Receipts under the EOPT
  law).
- Each invoice has an "Export EIS-draft JSON" button that outputs the
  invoice's data using field names that match what's publicly documented
  about BIR's EIS JSON schema (v2.01) — `EisUniqueId`, `IssueDtm`, `Tin`,
  `BranchCd`, `ItemList`, `SalesAmt`, `NetSales`, and so on. This is
  reference/draft output only, clearly labeled as such in the file — it is
  **not** a certified or transmittable payload.

## What genuinely can't be built yet — and why

BIR's e-invoicing requirement isn't just a file format. To actually
transmit a certified electronic invoice to BIR, a taxpayer needs, in
order:

1. **A Permit to Issue (PTI) Electronic Invoice** — applied for at the
   taxpayer's RDO, specific to that one business. BIR's processing target
   is 20 working days.
2. **Access to BIR's EIS Certification Portal**
   (`eis-cert.bir.gov.ph`) — this only opens up after the PTI is issued,
   and it's where the *complete, authoritative* v2.01 schema, test cases,
   and certification steps live. No public developer sandbox exists
   outside this portal, so there's no honest way to build or test the real
   transmission logic before a specific business has this access.
3. **EIS Certification** — a formal test-and-approval process, to be
   completed within 6 months of the PTI, that confirms the taxpayer's
   system produces valid, correctly signed invoices before it can go live.
4. **A BIR-issued signing certificate** — real invoices must be digitally
   signed (JWS) and the session encrypted (AES-256, with RSA used only to
   exchange the session key) before transmission, using credentials BIR
   issues as part of certification. There's nothing to plug in here until
   that certificate exists.

Because of this, "finish the EIS integration" isn't a coding task that can
be completed in advance — it's a per-business process that starts with
step 1 above. Building it blind and shipping it as "BIR-compliant"
would be dishonest, since Excel/Word-style static documents are explicitly
disqualified, and an unvetted from-scratch JSON/signing implementation
would have the same problem: nothing to test it against until a real PTI
and portal login exist.

## The actual next steps, when you're ready

1. Confirm which of your client businesses meet BIR's EIS coverage rules —
   most small businesses under the ₱3M "micro" revenue threshold are
   currently exempt outright and don't need any of this yet.
2. For a business that does need it (or wants to get ahead of it): apply
   for the Permit to Issue at their RDO.
3. Once the PTI is approved and portal access opens up, come back with the
   real schema/spec from the portal — at that point, adding the signing +
   transmission layer on top of this app's existing data model is a
   focused, well-scoped follow-up (the hard part — modeling the data
   correctly — is already done), not a rebuild.

## A note on "invoicing product for clients" vs. certification

BIR issues the Permit to Issue and certification to the taxpayer who owns
the business, not to whoever built their software. That means each client
business using this app would go through their own PTI/certification
process when the time comes — this app can support many businesses at
once, but it can't obtain a "group" permit on their behalf.
