// Renders the shared top bar into <div id="topbar"></div> and wires the
// business switcher + sign-out. Call renderNav(activePage) after DOM ready
// on every protected page.
async function renderNav(activePage) {
  const el = document.getElementById("topbar");
  if (!el) return;

  const businesses = await DB.myBusinesses();
  let currentId = CurrentBusiness.get();
  if (!businesses.find((b) => b.id === currentId)) {
    currentId = businesses[0] ? businesses[0].id : null;
    if (currentId) CurrentBusiness.set(currentId);
  }

  const switcherHtml =
    businesses.length > 1
      ? `<select id="bizSwitcher" style="width:auto; padding:6px 8px; margin-right:10px;">
           ${businesses.map((b) => `<option value="${b.id}" ${b.id === currentId ? "selected" : ""}>${escapeHtml(b.name)}</option>`).join("")}
         </select>`
      : businesses.length === 1
      ? `<span style="margin-right:14px; color:#cfe0ff; font-size:0.9rem;">${escapeHtml(businesses[0].name)}</span>`
      : "";

  const links = [
    ["app.html", "Dashboard"],
    ["new-invoice.html", "New Invoice"],
    ["customers.html", "Customers"],
    ["settings.html", "Settings"],
  ];

  el.innerHTML = `
    <div class="brand">Invoicing</div>
    <div style="display:flex; align-items:center; flex-wrap:wrap;">
      ${switcherHtml}
      <nav>
        ${links.map(([href, label]) => `<a href="${href}" style="${activePage === href ? "color:#fff;font-weight:700;" : ""}">${label}</a>`).join("")}
        <a href="#" id="signOutLink">Sign out</a>
      </nav>
    </div>
  `;

  const switcher = document.getElementById("bizSwitcher");
  if (switcher) {
    switcher.addEventListener("change", () => {
      CurrentBusiness.set(switcher.value);
      window.location.reload();
    });
  }

  document.getElementById("signOutLink").addEventListener("click", async (e) => {
    e.preventDefault();
    await DB.signOut();
    CurrentBusiness.clear();
    window.location.href = "index.html";
  });

  return { businesses, currentId };
}
