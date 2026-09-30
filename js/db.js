// Thin wrapper around Supabase calls. Every function throws on error so
// callers can wrap in try/catch and show a toast.

const DB = {
  async signUp(email, password) {
    const { data, error } = await supabaseClient.auth.signUp({ email, password });
    if (error) throw error;
    return data;
  },

  async signIn(email, password) {
    const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  },

  async signOut() {
    const { error } = await supabaseClient.auth.signOut();
    if (error) throw error;
  },

  async getSession() {
    const { data, error } = await supabaseClient.auth.getSession();
    if (error) throw error;
    return data.session;
  },

  async myBusinesses() {
    const { data, error } = await supabaseClient
      .from("businesses")
      .select("id, name, tin, address, vat_registered, invoice_prefix, branch_code, next_invoice_seq")
      .order("name");
    if (error) throw error;
    return data;
  },

  async createBusiness({ name, tin, address, vat_registered, invoice_prefix }) {
    const { data, error } = await supabaseClient.rpc("fn_create_business", {
      p_name: name,
      p_tin: tin,
      p_address: address,
      p_vat_registered: vat_registered,
      p_invoice_prefix: invoice_prefix,
    });
    if (error) throw error;
    return data; // new business id
  },

  async updateBusiness(id, fields) {
    const { error } = await supabaseClient.from("businesses").update(fields).eq("id", id);
    if (error) throw error;
  },

  async listCustomers(businessId) {
    const { data, error } = await supabaseClient
      .from("customers")
      .select("*")
      .eq("business_id", businessId)
      .order("name");
    if (error) throw error;
    return data;
  },

  async createCustomer(businessId, { name, tin, address }) {
    const { data, error } = await supabaseClient
      .from("customers")
      .insert({ business_id: businessId, name, tin, address })
      .select()
      .single();
    if (error) throw error;
    return data;
  },

  async listInvoices(businessId) {
    const { data, error } = await supabaseClient
      .from("invoices")
      .select("*")
      .eq("business_id", businessId)
      .order("issue_date", { ascending: false })
      .order("invoice_no", { ascending: false });
    if (error) throw error;
    return data;
  },

  async getInvoice(invoiceId) {
    const { data, error } = await supabaseClient
      .from("invoices")
      .select("*")
      .eq("id", invoiceId)
      .single();
    if (error) throw error;
    return data;
  },

  async getInvoiceItems(invoiceId) {
    const { data, error } = await supabaseClient
      .from("invoice_items")
      .select("*")
      .eq("invoice_id", invoiceId)
      .order("sort_order");
    if (error) throw error;
    return data;
  },

  async createInvoice({ businessId, customerId, customerName, customerTin, customerAddress, issueDate, items, vatTreatment }) {
    const { data, error } = await supabaseClient.rpc("fn_create_invoice", {
      p_business_id: businessId,
      p_customer_id: customerId,
      p_customer_name: customerName,
      p_customer_tin: customerTin,
      p_customer_address: customerAddress,
      p_issue_date: issueDate,
      p_items: items.map((it) => ({ description: it.description, qty: it.qty, unit_price: it.unit_price })),
      p_vat_treatment: vatTreatment || "standard",
    });
    if (error) throw error;
    return data; // new invoice id
  },

  async voidInvoice(invoiceId) {
    const { error } = await supabaseClient.rpc("fn_void_invoice", { p_invoice_id: invoiceId });
    if (error) throw error;
  },

  async listTeamMembers(businessId) {
    const { data, error } = await supabaseClient
      .from("business_members")
      .select("id, role, member_email, created_at")
      .eq("business_id", businessId)
      .order("created_at");
    if (error) throw error;
    return data;
  },

  async listPendingInvites(businessId) {
    const { data, error } = await supabaseClient
      .from("business_invites")
      .select("id, email, role, created_at")
      .eq("business_id", businessId)
      .is("accepted_at", null)
      .order("created_at");
    if (error) throw error;
    return data;
  },

  async inviteMember(businessId, email, role) {
    const { error } = await supabaseClient
      .from("business_invites")
      .insert({ business_id: businessId, email: email.trim().toLowerCase(), role });
    if (error) throw error;
  },

  async cancelInvite(inviteId) {
    const { error } = await supabaseClient.from("business_invites").delete().eq("id", inviteId);
    if (error) throw error;
  },

  async removeMember(memberId) {
    const { error } = await supabaseClient.from("business_members").delete().eq("id", memberId);
    if (error) throw error;
  },

  async acceptPendingInvites() {
    const { data, error } = await supabaseClient.rpc("fn_accept_pending_invites");
    if (error) throw error;
    return data; // number of invites accepted
  },
};

// ----------------------------------------------------------------------------
// Current-business selection, persisted per browser tab/user in localStorage.
// ----------------------------------------------------------------------------
const CurrentBusiness = {
  KEY: "invoicing_current_business_id",
  get() {
    return localStorage.getItem(this.KEY);
  },
  set(id) {
    localStorage.setItem(this.KEY, id);
  },
  clear() {
    localStorage.removeItem(this.KEY);
  },
};

// Redirect to login if not authenticated. Call at the top of every
// protected page. Also picks up any pending invites for this email —
// once per browser tab session, not on every single page load.
async function requireAuth() {
  const session = await DB.getSession();
  if (!session) {
    window.location.href = "index.html";
    return null;
  }
  if (!sessionStorage.getItem("invites_checked")) {
    sessionStorage.setItem("invites_checked", "1");
    try {
      const accepted = await DB.acceptPendingInvites();
      if (accepted > 0) {
        toast(`You now have access to ${accepted} business${accepted === 1 ? "" : "es"}.`);
      }
    } catch (e) {
      // non-fatal — worst case, a pending invite is picked up on next sign-in
    }
  }
  return session;
}
