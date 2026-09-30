// Shared helpers used across pages.

function peso(amount) {
  const n = Number(amount || 0);
  return "₱" + n.toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function fmtDate(d) {
  if (!d) return "";
  const dt = new Date(d + "T00:00:00");
  return dt.toLocaleDateString("en-PH", { year: "numeric", month: "short", day: "numeric" });
}

// Client-side preview only — the database function fn_create_invoice is the
// source of truth and recomputes this itself on save.
function computeVatPreview(items, vatRegistered) {
  const gross = items.reduce((sum, it) => sum + (Number(it.qty) || 0) * (Number(it.unit_price) || 0), 0);
  let vat = 0, net = gross;
  if (vatRegistered) {
    vat = round2(gross - gross / 1.12);
    net = round2(gross - vat);
  }
  return { gross: round2(gross), vat, net };
}

function round2(n) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

function qs(name) {
  return new URLSearchParams(window.location.search).get(name);
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str == null ? "" : String(str);
  return div.innerHTML;
}

function toast(msg, isError) {
  let el = document.getElementById("toast");
  if (!el) {
    el = document.createElement("div");
    el.id = "toast";
    document.body.appendChild(el);
  }
  el.textContent = msg;
  el.className = "toast" + (isError ? " toast-error" : "");
  el.style.display = "block";
  clearTimeout(el._t);
  el._t = setTimeout(() => { el.style.display = "none"; }, 4000);
}

// ----------------------------------------------------------------------------
// EIS-ready JSON export.
//
// IMPORTANT: this mirrors publicly-documented BIR EIS v2.01 field NAMES as a
// best-effort preview so an invoice's data is already structured close to
// what BIR's e-invoicing schema expects. It is NOT a certified or
// transmittable payload: real submission requires a taxpayer-specific
// Permit to Issue, the official schema from BIR's EIS Certification Portal
// (eis-cert.bir.gov.ph), and cryptographic signing/encryption with a
// BIR-issued certificate. Treat this export as a draft/reference only.
// ----------------------------------------------------------------------------
function buildEisDraftJson(business, invoice, items) {
  return {
    _note: "DRAFT / UNOFFICIAL — for reference only, not a certified BIR EIS payload. See docs/EIS_ROADMAP.md.",
    EisUniqueId: null, // assigned by BIR's system at certification/transmission time, not by this app
    IssueDtm: (invoice.issue_date || "").replaceAll("-", ""),
    Seller: {
      Tin: (business.tin || "").replaceAll("-", ""),
      BranchCd: business.branch_code || "00000",
      Name: business.name,
      Address: business.address || "",
    },
    Buyer: {
      Tin: (invoice.customer_tin_snapshot || "").replaceAll("-", ""),
      Name: invoice.customer_name_snapshot,
      Address: invoice.customer_address_snapshot || "",
    },
    InvoiceNo: invoice.invoice_no,
    VatRegistered: !!invoice.vat_registered_snapshot,
    SalesAmt: Number(invoice.gross_amount),
    VatAmt: Number(invoice.vat_amount),
    NetSales: Number(invoice.net_of_vat),
    ItemList: items.map((it, idx) => ({
      LineNo: idx + 1,
      Description: it.description,
      Qty: Number(it.qty),
      UnitPrice: Number(it.unit_price),
      LineTotal: Number(it.line_total),
    })),
  };
}

function downloadJson(filename, obj) {
  const blob = new Blob([JSON.stringify(obj, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
