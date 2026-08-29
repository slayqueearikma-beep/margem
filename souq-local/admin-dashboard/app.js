/* Dribex Admin — marketplace & category management */

const TOKEN_KEY = "margem_admin_token";
const DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

const state = {
  token: sessionStorage.getItem(TOKEN_KEY) || "",
  page: 1,
  pageSize: 10,
  editingMarketplaceId: null,
  editingCategoryId: null,
  marketplaces: [],
  categories: [],
  categorySortable: null,
  users: [],
  usersTotal: 0,
  usersPage: 1,
  usersPageSize: 50,
  staffRole: "",
  reports: [],
  advertisements: [],
  advertisementMeta: null,
  advertisingOverview: null,
  editingAdvertisementId: null,
  pendingMfaToken: "",
};

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => [...document.querySelectorAll(sel)];

function apiBase() {
  const configured = (window.MARGEM_API_URL || "").trim();
  if (configured) return configured.replace(/\/$/, "");
  return window.location.origin;
}

function authHeaders() {
  const headers = { "Content-Type": "application/json" };
  if (state.token) {
    headers.Authorization = `Bearer ${state.token}`;
  }
  return headers;
}

function formatApiError(detail, fallback = "Request failed") {
  if (typeof detail === "string" && detail.trim()) return detail;
  if (Array.isArray(detail)) {
    const messages = detail
      .map((item) => {
        if (typeof item === "string") return item;
        if (item && typeof item.msg === "string") return item.msg;
        return null;
      })
      .filter(Boolean);
    if (messages.length) return messages.join(", ");
  }
  return fallback;
}

async function api(path, options = {}) {
  const res = await fetch(`${apiBase()}${path}`, {
    ...options,
    headers: { ...authHeaders(), ...(options.headers || {}) },
  });
  if (res.status === 401) {
    logout();
    throw new Error("Session expired. Please sign in again.");
  }
  if (res.status === 204) return null;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = data.detail;
    throw new Error(formatApiError(detail));
  }
  return data;
}

function toast(message, isError = false) {
  const el = $("#toast");
  el.textContent = message;
  el.style.background = isError ? "#b42318" : "#1f1a17";
  el.classList.remove("hidden");
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => el.classList.add("hidden"), 3200);
}

function slugify(value) {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function showScreen(name) {
  $("#login-screen").classList.toggle("hidden", name !== "login");
  $("#app-screen").classList.toggle("hidden", name !== "app");
}

function logout() {
  state.token = "";
  state.pendingMfaToken = "";
  sessionStorage.removeItem(TOKEN_KEY);
  const mfaField = $("#mfa-field");
  const mfaCode = $("#login-mfa-code");
  const submitBtn = $("#login-submit-btn");
  if (mfaField) mfaField.classList.add("hidden");
  if (mfaCode) mfaCode.value = "";
  if (submitBtn) submitBtn.textContent = "Sign in";
  showScreen("login");
}

async function loginWithPassword(email, password) {
  const res = await fetch(`${apiBase()}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(formatApiError(data.detail, "Login failed"));
  }
  return data;
}

async function loginWithMfa(mfaToken, code) {
  const res = await fetch(`${apiBase()}/auth/mfa/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ mfa_token: mfaToken, code: code.trim() }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(formatApiError(data.detail, "Invalid authenticator code"));
  }
  return data;
}

async function finalizeStaffLogin(data) {
  const token = (data.access_token || "").trim();
  if (!token) {
    throw new Error("Login did not return an access token.");
  }
  state.token = token;
  state.pendingMfaToken = "";
  sessionStorage.setItem(TOKEN_KEY, state.token);
  const meRes = await fetch(`${apiBase()}/auth/me`, {
    headers: authHeaders(),
  });
  const me = await meRes.json().catch(() => ({}));
  if (!meRes.ok) {
    throw new Error(formatApiError(me.detail, "Could not verify account"));
  }
  if (me.role !== "admin" && me.role !== "support") {
    logout();
    throw new Error("This account does not have staff access.");
  }
  state.staffRole = me.role || "";
  $("#login-error").classList.add("hidden");
  $("#mfa-field").classList.add("hidden");
  $("#login-mfa-code").value = "";
  $("#login-submit-btn").textContent = "Sign in";
  showScreen("app");
  await bootstrapApp();
}

function switchView(view) {
  $$(".tab").forEach((tab) => tab.classList.toggle("active", tab.dataset.view === view));
  $("#view-marketplaces").classList.toggle("hidden", view !== "marketplaces");
  $("#view-categories").classList.toggle("hidden", view !== "categories");
  $("#view-users").classList.toggle("hidden", view !== "users");
  $("#view-reports").classList.toggle("hidden", view !== "reports");
  $("#view-advertisements").classList.toggle("hidden", view !== "advertisements");
  if (view === "categories") loadCategoryMarketplaceOptions();
  if (view === "users") loadUsers().catch((e) => toast(e.message, true));
  if (view === "reports") loadReports().catch((e) => toast(e.message, true));
  if (view === "advertisements") loadAdvertisements().catch((e) => toast(e.message, true));
}

function formatDate(value) {
  if (!value) return "—";
  try {
    return new Date(value).toLocaleString();
  } catch (_) {
    return value;
  }
}

function roleLabel(role) {
  return String(role || "customer").replace(/_/g, " ");
}

function statusPillClass(status) {
  const value = String(status || "active").toLowerCase();
  if (value === "suspended") return "suspended";
  if (value === "deleted") return "deleted";
  return "active";
}

async function loadReports() {
  const status = $("#reports-status-filter").value;
  const params = new URLSearchParams({ limit: "100" });
  if (status) params.set("status_filter", status);
  const rows = await api(`/admin/discovery/reports?${params.toString()}`);
  state.reports = rows || [];
  renderReports();
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function safeHttpUrl(url, fallback = "") {
  if (!url) return fallback;
  try {
    const parsed = new URL(String(url));
    if (parsed.protocol === "https:" || parsed.protocol === "http:") {
      return parsed.href;
    }
  } catch (_) {
    /* ignore */
  }
  return fallback;
}

function renderReports() {
  const tbody = $("#reports-tbody");
  tbody.innerHTML = "";
  if (!state.reports.length) {
    $("#reports-empty").classList.remove("hidden");
    return;
  }
  $("#reports-empty").classList.add("hidden");
  for (const report of state.reports) {
    const tr = document.createElement("tr");
    const target = escapeHtml(
      String(report.seller_id || report.product_id || report.reported_user_id || "—")
    );
    tr.innerHTML = `
      <td>${formatDate(report.created_at)}</td>
      <td>${escapeHtml(report.reason || "")}</td>
      <td><span class="pill ${escapeHtml(report.status || "")}">${escapeHtml(report.status || "")}</span></td>
      <td class="mono">${target}</td>
      <td class="actions">
        <button type="button" class="btn ghost sm" data-report-action="review" data-id="${report.id}">Review</button>
        <button type="button" class="btn ghost sm" data-report-action="resolve" data-id="${report.id}">Resolve</button>
        <button type="button" class="btn ghost sm" data-report-action="reject" data-id="${report.id}">Reject</button>
      </td>`;
    tbody.appendChild(tr);
  }
}

async function loadUsers() {
  const params = new URLSearchParams({
    limit: String(state.usersPageSize),
    offset: String((state.usersPage - 1) * state.usersPageSize),
  });
  const q = $("#users-search").value.trim();
  const role = $("#users-role-filter").value;
  const status = $("#users-status-filter").value;
  if (q) params.set("q", q);
  if (role) params.set("role", role);
  if (status) params.set("status", status);

  const data = await api(`/admin/users?${params.toString()}`);
  state.users = data.items || [];
  state.usersTotal = data.total || 0;
  renderUsers();
  renderUsersPagination();
}

function renderUsers() {
  const tbody = $("#users-tbody");
  tbody.innerHTML = "";
  const isAdmin = state.staffRole === "admin";
  const showingStart = state.usersTotal === 0 ? 0 : (state.usersPage - 1) * state.usersPageSize + 1;
  const showingEnd = Math.min(state.usersPage * state.usersPageSize, state.usersTotal);

  $("#users-total-stat").textContent = String(state.usersTotal);
  $("#users-showing-stat").textContent = state.usersTotal
    ? `${showingStart}–${showingEnd}`
    : "0";
  $("#users-role-stat").textContent = roleLabel(state.staffRole);
  $("#users-empty").classList.toggle("hidden", state.users.length > 0);

  state.users.forEach((user) => {
    const tr = document.createElement("tr");
    const role = String(user.role || "customer");
    const status = String(user.status || "active");
    const canSuspend = isAdmin && status === "active";
    const canRestore = isAdmin && status === "suspended";
    tr.innerHTML = `
      <td>${escapeHtml(user.email || "")}</td>
      <td>${escapeHtml(user.display_name || "—")}</td>
      <td><span class="status-pill ${role === "admin" || role === "support" ? role : ""}">${escapeHtml(roleLabel(role))}</span></td>
      <td>${escapeHtml(user.account_type || "—")}</td>
      <td><span class="status-pill ${statusPillClass(status)}">${escapeHtml(status)}</span></td>
      <td>${user.is_premium ? "Yes" : "No"}</td>
      <td>${formatDate(user.created_at)}</td>
      <td class="actions">
        <button type="button" class="btn sm ghost" data-user-action="copy" data-id="${user.id}" title="Copy user ID">Copy ID</button>
        ${canSuspend ? `<button type="button" class="btn sm danger" data-user-action="suspend" data-id="${user.id}">Suspend</button>` : ""}
        ${canRestore ? `<button type="button" class="btn sm" data-user-action="restore" data-id="${user.id}">Restore</button>` : ""}
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function renderUsersPagination() {
  const totalPages = Math.max(1, Math.ceil(state.usersTotal / state.usersPageSize));
  const container = $("#users-pagination");
  container.innerHTML = `
    <span>Page ${state.usersPage} of ${totalPages} · ${state.usersTotal} accounts</span>
    <div class="pages">
      <button type="button" class="btn sm ghost" id="users-prev" ${state.usersPage <= 1 ? "disabled" : ""}>Previous</button>
      <button type="button" class="btn sm ghost" id="users-next" ${state.usersPage >= totalPages ? "disabled" : ""}>Next</button>
    </div>
  `;
  $("#users-prev").onclick = () => {
    if (state.usersPage > 1) {
      state.usersPage -= 1;
      loadUsers().catch((e) => toast(e.message, true));
    }
  };
  $("#users-next").onclick = () => {
    const totalPages = Math.max(1, Math.ceil(state.usersTotal / state.usersPageSize));
    if (state.usersPage < totalPages) {
      state.usersPage += 1;
      loadUsers().catch((e) => toast(e.message, true));
    }
  };
}

function buildOpeningHoursFields(hours = {}) {
  const container = $("#opening-hours-fields");
  container.innerHTML = "";
  DAYS.forEach((day) => {
    const dayData = hours[day] || { open: "09:00", close: "20:00", closed: false };
    const row = document.createElement("div");
    row.className = "day-row";
    row.innerHTML = `
      <span>${day.slice(0, 3)}</span>
      <input type="time" data-day="${day}" data-field="open" value="${dayData.open || "09:00"}" />
      <input type="time" data-day="${day}" data-field="close" value="${dayData.close || "20:00"}" />
      <label class="checkbox-label"><input type="checkbox" data-day="${day}" data-field="closed" ${dayData.closed ? "checked" : ""} /> Closed</label>
    `;
    container.appendChild(row);
  });
}

function readOpeningHours() {
  const hours = {};
  DAYS.forEach((day) => {
    hours[day] = {
      open: containerValue(day, "open") || "09:00",
      close: containerValue(day, "close") || "20:00",
      closed: containerChecked(day, "closed"),
    };
  });
  return hours;
}

function containerValue(day, field) {
  return document.querySelector(`[data-day="${day}"][data-field="${field}"]`)?.value;
}

function containerChecked(day, field) {
  return document.querySelector(`[data-day="${day}"][data-field="${field}"]`)?.checked || false;
}

async function uploadImage(file, targetInput) {
  const presign = await api("/uploads/presign", {
    method: "POST",
    body: JSON.stringify({ filename: file.name, content_type: file.type || "image/jpeg" }),
  });
  const uploadRes = await fetch(presign.upload_url, {
    method: "PUT",
    headers: { "Content-Type": file.type || "image/jpeg", "x-ms-blob-type": "BlockBlob" },
    body: file,
  });
  if (!uploadRes.ok) throw new Error("Image upload failed");
  targetInput.value = presign.public_url;
  toast("Image uploaded");
}

function bindUploadInputs(root) {
  root.querySelectorAll("input[type=file][data-upload-target]").forEach((input) => {
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) return;
      const target = root.querySelector(`[name="${input.dataset.uploadTarget}"]`);
      if (!target) return;
      try {
        await uploadImage(file, target);
      } catch (err) {
        toast(err.message, true);
      }
    };
  });
}

async function loadMarketplaces() {
  const params = new URLSearchParams({
    page: String(state.page),
    page_size: String(state.pageSize),
    sort: $("#mp-sort").value,
    order: $("#mp-order").value,
    status_filter: $("#mp-status-filter").value,
  });
  const search = $("#mp-search").value.trim();
  const city = $("#mp-city-filter").value.trim();
  if (search) params.set("search", search);
  if (city) params.set("city", city);

  const data = await api(`/admin/marketplaces?${params}`);
  state.marketplaces = data.items;
  renderMarketplaceStats(data.stats);
  renderMarketplaceTable(data);
  renderPagination(data);
}

function renderMarketplaceStats(stats) {
  $$("#marketplace-stats [data-stat]").forEach((el) => {
    el.textContent = stats[el.dataset.stat] ?? "0";
  });
}

function renderMarketplaceTable(data) {
  const tbody = $("#marketplaces-tbody");
  tbody.innerHTML = "";
  data.items.forEach((mp) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>
        <div class="mp-cell">
          <img class="mp-logo" src="${safeHttpUrl(mp.logo_image_url, "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='44' height='44'%3E%3Crect fill='%23f3ebe2' width='44' height='44' rx='12'/%3E%3C/svg%3E")}" alt="" />
          <div>
            <strong>${escapeHtml(mp.name)}</strong><br />
            <span class="muted">${escapeHtml(mp.slug)}</span>
          </div>
        </div>
      </td>
      <td>${escapeHtml(mp.district || "—")}, ${escapeHtml(mp.city)}</td>
      <td>${mp.category_count}</td>
      <td>${mp.seller_count}</td>
      <td>${mp.display_order}</td>
      <td>
        <span class="status-pill ${mp.is_active ? "active" : "hidden"}">
          ${mp.is_active ? "Active" : "Hidden"}
        </span>
      </td>
      <td>
        <div class="actions">
          <button class="btn sm ghost" data-action="preview" data-id="${mp.id}">Preview</button>
          <button class="btn sm ghost" data-action="edit" data-id="${mp.id}">Edit</button>
          <button class="btn sm ghost" data-action="categories" data-id="${mp.id}">Categories</button>
          <button class="btn sm ghost" data-action="toggle" data-id="${mp.id}" data-active="${mp.is_active}">
            ${mp.is_active ? "Hide" : "Unhide"}
          </button>
          <button class="btn sm danger" data-action="delete" data-id="${mp.id}">Delete</button>
        </div>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function renderPagination(data) {
  const totalPages = Math.max(1, Math.ceil(data.total / data.page_size));
  const el = $("#mp-pagination");
  el.innerHTML = `
    <span>Showing ${data.items.length} of ${data.total}</span>
    <div class="pages">
      <button class="btn sm ghost" ${data.page <= 1 ? "disabled" : ""} data-page="${data.page - 1}">Prev</button>
      <span>Page ${data.page} / ${totalPages}</span>
      <button class="btn sm ghost" ${data.page >= totalPages ? "disabled" : ""} data-page="${data.page + 1}">Next</button>
    </div>
  `;
  el.querySelectorAll("[data-page]").forEach((btn) => {
    btn.onclick = () => {
      state.page = Number(btn.dataset.page);
      loadMarketplaces().catch((e) => toast(e.message, true));
    };
  });
}

function openMarketplaceDialog(mp = null) {
  state.editingMarketplaceId = mp?.id || null;
  const form = $("#marketplace-form");
  form.reset();
  $("#marketplace-dialog-title").textContent = mp ? "Edit marketplace" : "New marketplace";
  if (mp) {
    Object.entries(mp).forEach(([key, value]) => {
      const input = form.elements.namedItem(key);
      if (!input) return;
      if (input.type === "checkbox") input.checked = Boolean(value);
      else input.value = value ?? "";
    });
    buildOpeningHoursFields(mp.opening_hours || {});
  } else {
    form.elements.city.value = "Casablanca";
    form.elements.is_active.checked = true;
    buildOpeningHoursFields();
  }
  bindUploadInputs(form);
  $("#marketplace-dialog").showModal();
}

async function saveMarketplace(event) {
  event.preventDefault();
  const form = event.target;
  const payload = {
    name: form.elements.name.value.trim(),
    slug: form.elements.slug.value.trim(),
    description: form.elements.description.value.trim(),
    address: form.elements.address.value.trim(),
    district: form.elements.district.value.trim(),
    city: form.elements.city.value.trim() || "Casablanca",
    latitude: Number(form.elements.latitude.value || 0),
    longitude: Number(form.elements.longitude.value || 0),
    cover_image_url: form.elements.cover_image_url.value.trim(),
    logo_image_url: form.elements.logo_image_url.value.trim(),
    opening_hours: readOpeningHours(),
    is_active: form.elements.is_active.checked,
    display_order: Number(form.elements.display_order.value || 0),
  };
  try {
    if (state.editingMarketplaceId) {
      await api(`/admin/marketplaces/${state.editingMarketplaceId}`, {
        method: "PATCH",
        body: JSON.stringify(payload),
      });
      toast("Marketplace updated");
    } else {
      await api("/admin/marketplaces", { method: "POST", body: JSON.stringify(payload) });
      toast("Marketplace created");
    }
    $("#marketplace-dialog").close();
    await loadMarketplaces();
  } catch (err) {
    toast(err.message, true);
  }
}

function openPreview(mp) {
  const hours = Object.entries(mp.opening_hours || {})
    .map(([day, cfg]) => `<li><strong>${day}</strong>: ${cfg.closed ? "Closed" : `${cfg.open} – ${cfg.close}`}</li>`)
    .join("");
  $("#preview-body").innerHTML = `
    ${mp.cover_image_url ? `<img class="preview-cover" src="${safeHttpUrl(mp.cover_image_url)}" alt="" />` : ""}
    <div class="preview-head">
      ${mp.logo_image_url ? `<img class="preview-logo" src="${mp.logo_image_url}" alt="" />` : ""}
      <div>
        <h3 style="margin:0">${escapeHtml(mp.name)}</h3>
        <p class="muted" style="margin:0.25rem 0 0">${escapeHtml(mp.slug)} · ${escapeHtml(mp.city)}</p>
      </div>
    </div>
    <p>${escapeHtml(mp.description || "No description")}</p>
    <p><strong>Address:</strong> ${escapeHtml(mp.address || "—")}, ${escapeHtml(mp.district || "")}</p>
    <p><strong>Coordinates:</strong> ${mp.latitude}, ${mp.longitude}</p>
    <p><strong>Categories:</strong> ${mp.category_count} · <strong>Sellers:</strong> ${mp.seller_count}</p>
    <ul>${hours || "<li>Opening hours not set</li>"}</ul>
  `;
  $("#preview-dialog").showModal();
}

async function loadCategoryMarketplaceOptions() {
  const data = await api("/admin/marketplaces?page_size=100&status_filter=all&sort=name");
  const select = $("#category-marketplace-select");
  const current = select.value;
  select.innerHTML = `<option value="">Select marketplace…</option>`;
  data.items.forEach((mp) => {
    const opt = document.createElement("option");
    opt.value = mp.id;
    opt.textContent = mp.name;
    select.appendChild(opt);
  });
  if (current) select.value = current;
  $("#create-category-btn").disabled = !select.value;
}

async function loadCategories() {
  const marketplaceId = $("#category-marketplace-select").value;
  $("#create-category-btn").disabled = !marketplaceId;
  const list = $("#category-list");
  list.innerHTML = "";
  if (!marketplaceId) {
    $("#category-empty").classList.add("hidden");
    $("#category-marketplace-meta").textContent = "";
    return;
  }
  const includeHidden = $("#category-show-hidden").checked;
  const categories = await api(
    `/admin/marketplaces/${marketplaceId}/categories?include_hidden=${includeHidden}`
  );
  state.categories = categories;
  const mp = state.marketplaces.find((m) => m.id === marketplaceId)
    || (await api(`/admin/marketplaces/${marketplaceId}`));
  $("#category-marketplace-meta").textContent =
    `${mp.name} — ${categories.length} categories · drag rows to reorder`;
  $("#category-empty").classList.toggle("hidden", categories.length > 0);

  categories.forEach((cat) => list.appendChild(renderCategoryItem(cat)));
  initCategorySortable(marketplaceId);
  refreshParentOptions();
}

function renderCategoryItem(cat) {
  const li = document.createElement("li");
  li.className = `category-item${cat.is_active ? "" : " inactive"}`;
  li.dataset.id = cat.id;
  li.innerHTML = `
    <span class="drag-handle" title="Drag to reorder">⋮⋮</span>
    <div class="category-main">
      <strong>${escapeHtml(cat.name)}</strong>
      <small>${escapeHtml(cat.slug)} · icon: ${escapeHtml(cat.icon)} · order ${cat.display_order}</small>
    </div>
    <span class="status-pill ${cat.is_active ? "active" : "hidden"}">${cat.is_active ? "Active" : "Hidden"}</span>
    <div class="category-actions">
      <button class="btn sm ghost" data-cat-action="edit" data-id="${cat.id}">Edit</button>
      <button class="btn sm ghost" data-cat-action="toggle" data-id="${cat.id}" data-active="${cat.is_active}">
        ${cat.is_active ? "Hide" : "Unhide"}
      </button>
      <button class="btn sm danger" data-cat-action="delete" data-id="${cat.id}">Delete</button>
    </div>
  `;
  return li;
}

function initCategorySortable(marketplaceId) {
  const list = $("#category-list");
  if (state.categorySortable) state.categorySortable.destroy();
  state.categorySortable = Sortable.create(list, {
    handle: ".drag-handle",
    animation: 150,
    onEnd: async () => {
      const orderedIds = [...list.children].map((el) => el.dataset.id);
      try {
        await api(`/admin/marketplaces/${marketplaceId}/categories/reorder`, {
          method: "POST",
          body: JSON.stringify({ ordered_ids: orderedIds }),
        });
        toast("Category order saved");
        await loadCategories();
      } catch (err) {
        toast(err.message, true);
        await loadCategories();
      }
    },
  });
}

function refreshParentOptions(excludeId = null) {
  const select = $("#category-form select[name=parent_id]");
  const current = select.value;
  select.innerHTML = `<option value="">None (top level)</option>`;
  state.categories
    .filter((c) => c.id !== excludeId)
    .forEach((cat) => {
      const opt = document.createElement("option");
      opt.value = cat.id;
      opt.textContent = cat.name;
      select.appendChild(opt);
    });
  if (current) select.value = current;
}

function openCategoryDialog(cat = null) {
  const marketplaceId = $("#category-marketplace-select").value;
  if (!marketplaceId) return;
  state.editingCategoryId = cat?.id || null;
  const form = $("#category-form");
  form.reset();
  $("#category-dialog-title").textContent = cat ? "Edit category" : "New category";
  refreshParentOptions(cat?.id || null);
  if (cat) {
    form.elements.name.value = cat.name;
    form.elements.slug.value = cat.slug;
    form.elements.description.value = cat.description || "";
    form.elements.icon.value = cat.icon || "store";
    form.elements.display_order.value = cat.display_order ?? 0;
    form.elements.banner_image_url.value = cat.banner_image_url || "";
    form.elements.is_active.checked = cat.is_active;
    if (cat.parent_id) form.elements.parent_id.value = cat.parent_id;
  } else {
    form.elements.is_active.checked = true;
    form.elements.icon.value = "store";
  }
  bindUploadInputs(form);
  form.elements.name.oninput = () => {
    if (!state.editingCategoryId && !form.elements.slug.dataset.touched) {
      form.elements.slug.value = slugify(form.elements.name.value);
    }
  };
  form.elements.slug.oninput = () => {
    form.elements.slug.dataset.touched = "1";
  };
  $("#category-dialog").showModal();
}

async function saveCategory(event) {
  event.preventDefault();
  const marketplaceId = $("#category-marketplace-select").value;
  const form = event.target;
  const parent = form.elements.parent_id.value;
  const payload = {
    name: form.elements.name.value.trim(),
    slug: form.elements.slug.value.trim(),
    description: form.elements.description.value.trim(),
    icon: form.elements.icon.value.trim() || "store",
    display_order: Number(form.elements.display_order.value || 0),
    banner_image_url: form.elements.banner_image_url.value.trim(),
    is_active: form.elements.is_active.checked,
    parent_id: parent || null,
  };
  try {
    if (state.editingCategoryId) {
      await api(`/admin/marketplaces/${marketplaceId}/categories/${state.editingCategoryId}`, {
        method: "PATCH",
        body: JSON.stringify(payload),
      });
      toast("Category updated");
    } else {
      await api(`/admin/marketplaces/${marketplaceId}/categories`, {
        method: "POST",
        body: JSON.stringify(payload),
      });
      toast("Category created");
    }
    $("#category-dialog").close();
    await loadCategories();
    await loadMarketplaces();
  } catch (err) {
    toast(err.message, true);
  }
}

async function loadAdvertisementMeta() {
  if (state.advertisementMeta) return state.advertisementMeta;
  state.advertisementMeta = await api("/admin/advertisements/meta");
  return state.advertisementMeta;
}

function populatePlacementSelect(selected) {
  const select = $("#ad-placement-select");
  if (!select || !state.advertisementMeta) return;
  select.innerHTML = "";
  (state.advertisementMeta.placements || []).forEach((option) => {
    const el = document.createElement("option");
    el.value = option.value;
    el.textContent = option.label;
    if (option.value === selected) el.selected = true;
    select.appendChild(el);
  });
}

async function ensureMarketplacesLoaded() {
  if (state.marketplaces.length) return;
  const data = await api("/admin/marketplaces?page_size=100&status_filter=all&sort=name");
  state.marketplaces = data.items || [];
}

function populateAdMarketplaceSelect(selectedSlug = "") {
  const select = $("#ad-marketplace-select");
  if (!select) return;
  select.innerHTML = '<option value="">All marketplaces</option>';
  state.marketplaces.forEach((marketplace) => {
    const el = document.createElement("option");
    el.value = marketplace.slug;
    el.textContent = marketplace.name;
    if (marketplace.slug === selectedSlug) el.selected = true;
    select.appendChild(el);
  });
}

async function populateAdCategorySelect(marketplaceSlug = "", selectedSlug = "") {
  const select = $("#ad-category-select");
  if (!select) return;
  select.innerHTML = '<option value="">All categories</option>';
  if (!marketplaceSlug) {
    try {
      const categories = await api("/categories");
      categories.forEach((category) => {
        const el = document.createElement("option");
        el.value = category.slug;
        el.textContent = category.name_en || category.slug;
        if (category.slug === selectedSlug) el.selected = true;
        select.appendChild(el);
      });
    } catch {
      // Global categories are optional when no marketplace is selected.
    }
    return;
  }
  const marketplace = state.marketplaces.find((item) => item.slug === marketplaceSlug);
  if (!marketplace) return;
  const categories = await api(
    `/admin/marketplaces/${marketplace.id}/categories?include_hidden=false`,
  );
  categories.forEach((category) => {
    const el = document.createElement("option");
    el.value = category.slug;
    el.textContent = category.name;
    if (category.slug === selectedSlug) el.selected = true;
    select.appendChild(el);
  });
}

function toDatetimeLocalValue(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const pad = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function fromDatetimeLocalValue(value) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
}

function renderAdvertisingOverview() {
  const container = $("#advertising-overview");
  if (!container) return;
  const stats = state.advertisingOverview || {};
  const cards = [
    ["Active", stats.active_campaigns || 0],
    ["Scheduled", stats.scheduled_campaigns || 0],
    ["Paused", stats.paused_campaigns || 0],
    ["Expired", stats.expired_campaigns || 0],
    ["Impressions", stats.total_impressions || 0],
    ["Clicks", stats.total_clicks || 0],
  ];
  container.innerHTML = cards
    .map(
      ([label, value]) => `
      <div class="stat-card">
        <p class="stat-label">${escapeHtml(label)}</p>
        <p class="stat-value">${escapeHtml(String(value))}</p>
      </div>`,
    )
    .join("");
}

async function loadAdvertisements() {
  await loadAdvertisementMeta();
  const [rows, overview] = await Promise.all([
    api("/admin/advertisements"),
    api("/admin/advertisements/overview"),
  ]);
  state.advertisements = rows || [];
  state.advertisingOverview = overview || {};
  renderAdvertisingOverview();
  renderAdvertisements();
}

function formatImpressions(ad) {
  if (ad.max_impressions) {
    return `${ad.impression_count || 0} / ${ad.max_impressions}`;
  }
  return String(ad.impression_count || 0);
}

function formatAdTargeting(ad) {
  const parts = [];
  if (ad.target_marketplace_slug) parts.push(`mp:${ad.target_marketplace_slug}`);
  if (ad.target_category_slug) parts.push(`cat:${ad.target_category_slug}`);
  if (ad.target_city) parts.push(`city:${ad.target_city}`);
  if (ad.target_platform && ad.target_platform !== "all") parts.push(ad.target_platform);
  return parts.length ? parts.join(" · ") : "All";
}

function renderAdminBuildStamp() {
  const stamp = $("#admin-build-stamp");
  if (!stamp) return;
  const build = window.MARGEM_ADMIN_BUILD || "dev";
  stamp.textContent = `Admin UI build ${build}`;
}

function renderAdvertisements() {
  const tbody = $("#advertisements-tbody");
  const empty = $("#advertisements-empty");
  tbody.innerHTML = "";
  if (!state.advertisements.length) {
    empty.classList.remove("hidden");
    return;
  }
  empty.classList.add("hidden");
  const placementLabels = Object.fromEntries(
    (state.advertisementMeta?.placements || []).map((item) => [item.value, item.label]),
  );
  state.advertisements.forEach((ad) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>
        <strong>${escapeHtml(ad.campaign_name || ad.title)}</strong>
        <div class="muted">${escapeHtml(ad.title)}</div>
      </td>
      <td>${escapeHtml(ad.advertiser_name || "—")}</td>
      <td>${escapeHtml(placementLabels[ad.placement] || ad.placement || "—")}</td>
      <td class="muted">${escapeHtml(formatAdTargeting(ad))}</td>
      <td><span class="pill ${ad.status === "active" ? "active" : "hidden-stat"}">${escapeHtml(ad.status || "—")}</span></td>
      <td>${escapeHtml(ad.payment_status || "—")}</td>
      <td>${escapeHtml(formatDate(ad.starts_at))}</td>
      <td>${escapeHtml(formatDate(ad.ends_at))}</td>
      <td>${escapeHtml(formatImpressions(ad))}</td>
      <td>${escapeHtml(String(ad.click_count || 0))}</td>
      <td class="actions">
        <button type="button" class="btn ghost sm" data-ad-action="preview" data-ad-id="${ad.id}">Preview</button>
        <button type="button" class="btn ghost sm" data-ad-action="edit" data-ad-id="${ad.id}">Edit</button>
        <button type="button" class="btn ghost sm" data-ad-action="pause" data-ad-id="${ad.id}">Pause</button>
        <button type="button" class="btn ghost sm" data-ad-action="resume" data-ad-id="${ad.id}">Resume</button>
        <button type="button" class="btn ghost sm danger" data-ad-action="delete" data-ad-id="${ad.id}">Delete</button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function openAdvertisementDialog(ad = null) {
  const dialog = $("#advertisement-dialog");
  const form = $("#advertisement-form");
  state.editingAdvertisementId = ad?.id || null;
  $("#advertisement-dialog-title").textContent = ad ? "Edit campaign" : "New campaign";
  populatePlacementSelect(ad?.placement || "homepage_top");
  void ensureMarketplacesLoaded().then(async () => {
    populateAdMarketplaceSelect(ad?.target_marketplace_slug || "");
    await populateAdCategorySelect(ad?.target_marketplace_slug || "", ad?.target_category_slug || "");
  });
  form.elements.advertiser_name.value = ad?.advertiser_name || "";
  form.elements.campaign_name.value = ad?.campaign_name || "";
  form.elements.title.value = ad?.title || "";
  form.elements.description.value = ad?.description || "";
  form.elements.image_url.value = ad?.image_url || "";
  form.elements.video_url.value = ad?.video_url || "";
  form.elements.target_url.value = ad?.target_url || "";
  form.elements.contact_info.value = ad?.contact_info || "";
  form.elements.placement.value = ad?.placement || "homepage_top";
  form.elements.starts_at.value = toDatetimeLocalValue(ad?.starts_at);
  form.elements.ends_at.value = toDatetimeLocalValue(ad?.ends_at);
  form.elements.status.value = ad?.status || "draft";
  form.elements.payment_status.value = ad?.payment_status || "pending";
  form.elements.priority.value = ad?.priority ?? 5;
  form.elements.max_impressions.value = ad?.max_impressions ?? "";
  form.elements.max_impressions_per_user_per_day.value = ad?.max_impressions_per_user_per_day ?? "";
  form.elements.min_interval_minutes.value = ad?.min_interval_minutes ?? "";
  form.elements.target_city.value = ad?.target_city || "";
  form.elements.target_marketplace_slug.value = ad?.target_marketplace_slug || "";
  form.elements.target_category_slug.value = ad?.target_category_slug || "";
  form.elements.target_listing_type.value = ad?.target_listing_type || "";
  form.elements.target_platform.value = ad?.target_platform || "all";
  form.elements.payment_override.checked = Boolean(ad?.payment_override);
  form.elements.internal_notes.value = ad?.internal_notes || "";
  bindUploadInputs(dialog);
  dialog.showModal();
}

function buildAdvertisementPayload(form) {
  const payload = {
    advertiser_name: form.elements.advertiser_name.value.trim(),
    campaign_name: form.elements.campaign_name.value.trim(),
    title: form.elements.title.value.trim(),
    description: form.elements.description.value.trim() || null,
    image_url: form.elements.image_url.value.trim(),
    video_url: form.elements.video_url.value.trim() || null,
    target_url: form.elements.target_url.value.trim(),
    contact_info: form.elements.contact_info.value.trim(),
    placement: form.elements.placement.value,
    starts_at: fromDatetimeLocalValue(form.elements.starts_at.value),
    ends_at: fromDatetimeLocalValue(form.elements.ends_at.value),
    status: form.elements.status.value,
    payment_status: form.elements.payment_status.value,
    priority: Number(form.elements.priority.value || 5),
    max_impressions: form.elements.max_impressions.value ? Number(form.elements.max_impressions.value) : null,
    max_impressions_per_user_per_day: form.elements.max_impressions_per_user_per_day.value
      ? Number(form.elements.max_impressions_per_user_per_day.value)
      : null,
    min_interval_minutes: form.elements.min_interval_minutes.value
      ? Number(form.elements.min_interval_minutes.value)
      : null,
    target_city: form.elements.target_city.value.trim() || null,
    target_marketplace_slug: form.elements.target_marketplace_slug.value.trim() || null,
    target_category_slug: form.elements.target_category_slug.value.trim() || null,
    target_listing_type: form.elements.target_listing_type.value || null,
    target_platform: form.elements.target_platform.value,
    payment_override: form.elements.payment_override.checked,
    internal_notes: form.elements.internal_notes.value.trim(),
  };
  return payload;
}

async function saveAdvertisement(event) {
  event.preventDefault();
  const form = event.target;
  const payload = buildAdvertisementPayload(form);
  try {
    if (state.editingAdvertisementId) {
      await api(`/admin/advertisements/${state.editingAdvertisementId}`, {
        method: "PATCH",
        body: JSON.stringify(payload),
      });
      toast("Campaign updated");
    } else {
      await api("/admin/advertisements", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      toast("Campaign created");
    }
    $("#advertisement-dialog").close();
    await loadAdvertisements();
  } catch (err) {
    toast(err.message, true);
  }
}

async function previewAdvertisement(adId) {
  const preview = await api(`/admin/advertisements/${adId}/preview`);
  const body = $("#ad-preview-body");
  body.innerHTML = `
    <div class="preview-card">
      ${preview.image_url ? `<img src="${escapeHtml(preview.image_url)}" alt="${escapeHtml(preview.title)}" class="preview-image" />` : ""}
      ${preview.video_url ? `<p class="muted">Video: ${escapeHtml(preview.video_url)}</p>` : ""}
      <h4>${escapeHtml(preview.title)}</h4>
      <p>${escapeHtml(preview.description || "")}</p>
      <p><strong>Placement:</strong> ${escapeHtml(preview.placement_label || preview.placement)}</p>
      <p><strong>Destination:</strong> <a href="${escapeHtml(preview.target_url)}" target="_blank" rel="noopener noreferrer">${escapeHtml(preview.target_url)}</a></p>
      <p><strong>Status:</strong> ${escapeHtml(preview.status)} · <strong>Payment:</strong> ${escapeHtml(preview.payment_status)}</p>
      <p><strong>Schedule:</strong> ${escapeHtml(formatDate(preview.starts_at))} → ${escapeHtml(formatDate(preview.ends_at))}</p>
      <p><strong>Targeting:</strong> marketplace=${escapeHtml(preview.target_marketplace_slug || "any")}, city=${escapeHtml(preview.target_city || "any")}, category=${escapeHtml(preview.target_category_slug || "any")}, listing=${escapeHtml(preview.target_listing_type || "any")}, platform=${escapeHtml(preview.target_platform || "all")}</p>
      <p><strong>Frequency:</strong> max ${escapeHtml(String(preview.max_impressions || "∞"))} impressions, ${escapeHtml(String(preview.max_impressions_per_user_per_day || "∞"))}/user/day, ${escapeHtml(String(preview.min_interval_minutes || "—"))} min interval</p>
      <p class="muted">Preview does not record impressions.</p>
    </div>
  `;
  $("#ad-preview-dialog").showModal();
}

function bindEvents() {
  $("#login-form").onsubmit = async (event) => {
    event.preventDefault();
    const email = $("#login-email").value.trim();
    const password = $("#login-password").value;
    const mfaCode = $("#login-mfa-code").value.trim();
    try {
      let loginData;
      if (state.pendingMfaToken) {
        if (!/^\d{6,8}$/.test(mfaCode)) {
          throw new Error("Enter the 6-digit code from your authenticator app.");
        }
        loginData = await loginWithMfa(state.pendingMfaToken, mfaCode);
      } else {
        loginData = await loginWithPassword(email, password);
        if (loginData.mfa_required) {
          state.pendingMfaToken = loginData.mfa_token || "";
          if (!state.pendingMfaToken) {
            throw new Error("Two-factor authentication is required but the server did not return a challenge token.");
          }
          $("#mfa-field").classList.remove("hidden");
          $("#login-submit-btn").textContent = "Verify code";
          $("#login-mfa-code").focus();
          $("#login-error").classList.add("hidden");
          return;
        }
      }
      await finalizeStaffLogin(loginData);
    } catch (err) {
      if (!state.pendingMfaToken) {
        logout();
      }
      $("#login-error").textContent = err.message;
      $("#login-error").classList.remove("hidden");
    }
  };

  $("#logout-btn").onclick = logout;
  $$(".tab").forEach((tab) => {
    tab.onclick = () => switchView(tab.dataset.view);
  });

  $("#refresh-users-btn").onclick = () => {
    state.usersPage = 1;
    loadUsers().catch((e) => toast(e.message, true));
  };
  $("#refresh-reports-btn").onclick = () => loadReports().catch((e) => toast(e.message, true));
  $("#reports-status-filter").onchange = () => loadReports().catch((e) => toast(e.message, true));
  $("#reports-tbody").onclick = async (event) => {
    const btn = event.target.closest("[data-report-action]");
    if (!btn) return;
    const id = btn.dataset.id;
    const action = btn.dataset.reportAction;
    const statusMap = { review: "under_review", resolve: "resolved", reject: "rejected" };
    const status = statusMap[action];
    if (!status) return;
    try {
      await api(`/admin/discovery/reports/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ status, resolution_notes: `Marked ${status} from admin dashboard` }),
      });
      toast(`Report ${status.replace("_", " ")}`);
      await loadReports();
    } catch (err) {
      toast(err.message, true);
    }
  };
  $("#users-search").oninput = debounce(() => {
    state.usersPage = 1;
    loadUsers().catch((e) => toast(e.message, true));
  }, 300);
  ["users-role-filter", "users-status-filter"].forEach((id) => {
    $(`#${id}`).onchange = () => {
      state.usersPage = 1;
      loadUsers().catch((e) => toast(e.message, true));
    };
  });
  $("#users-tbody").onclick = async (event) => {
    const btn = event.target.closest("button[data-user-action]");
    if (!btn) return;
    const userId = btn.dataset.id;
    const action = btn.dataset.userAction;
    try {
      if (action === "copy") {
        await navigator.clipboard.writeText(userId);
        toast("User ID copied");
        return;
      }
      if (action === "suspend") {
        if (!confirm("Suspend this user? They will not be able to sign in.")) return;
        await api(`/admin/users/${userId}/status?status=suspended`, { method: "PATCH" });
        toast("User suspended");
      }
      if (action === "restore") {
        await api(`/admin/users/${userId}/status?status=active`, { method: "PATCH" });
        toast("User restored");
      }
      await loadUsers();
    } catch (err) {
      toast(err.message, true);
    }
  };

  $("#create-marketplace-btn").onclick = () => openMarketplaceDialog();
  $("#marketplace-form").onsubmit = saveMarketplace;
  $("#create-advertisement-btn").onclick = () => openAdvertisementDialog();
  $("#advertisement-form").onsubmit = saveAdvertisement;
  $("#ad-marketplace-select")?.addEventListener("change", async (event) => {
    await populateAdCategorySelect(event.target.value, "");
  });
  $("#advertisements-tbody").onclick = async (event) => {
    const btn = event.target.closest("button[data-ad-action]");
    if (!btn) return;
    const ad = state.advertisements.find((row) => row.id === btn.dataset.adId);
    if (!ad) return;
    const action = btn.dataset.adAction;
    try {
      if (action === "edit") {
        openAdvertisementDialog(ad);
        return;
      }
      if (action === "preview") {
        await previewAdvertisement(ad.id);
        return;
      }
      if (action === "pause") {
        await api(`/admin/advertisements/${ad.id}/pause`, { method: "POST" });
        toast("Campaign paused");
        await loadAdvertisements();
        return;
      }
      if (action === "resume") {
        await api(`/admin/advertisements/${ad.id}/resume`, { method: "POST" });
        toast("Campaign resumed");
        await loadAdvertisements();
        return;
      }
      if (action === "delete") {
        if (!confirm(`Delete campaign "${ad.campaign_name || ad.title}"? Historical statistics are retained.`)) return;
        await api(`/admin/advertisements/${ad.id}`, { method: "DELETE" });
        toast("Campaign deleted");
        await loadAdvertisements();
      }
    } catch (err) {
      toast(err.message, true);
    }
  };

  ["mp-search", "mp-city-filter"].forEach((id) => {
    $(`#${id}`).oninput = debounce(() => {
      state.page = 1;
      loadMarketplaces().catch((e) => toast(e.message, true));
    }, 300);
  });
  ["mp-status-filter", "mp-sort", "mp-order"].forEach((id) => {
    $(`#${id}`).onchange = () => {
      state.page = 1;
      loadMarketplaces().catch((e) => toast(e.message, true));
    };
  });

  $("#marketplaces-tbody").onclick = async (event) => {
    const btn = event.target.closest("button[data-action]");
    if (!btn) return;
    const id = btn.dataset.id;
    const mp = state.marketplaces.find((m) => m.id === id) || await api(`/admin/marketplaces/${id}`);
    const action = btn.dataset.action;
    try {
      if (action === "preview") openPreview(mp);
      if (action === "edit") openMarketplaceDialog(mp);
      if (action === "categories") {
        switchView("categories");
        $("#category-marketplace-select").value = id;
        await loadCategories();
      }
      if (action === "toggle") {
        const path = mp.is_active ? "hide" : "unhide";
        await api(`/admin/marketplaces/${id}/${path}`, { method: "POST" });
        toast(mp.is_active ? "Marketplace hidden" : "Marketplace activated");
        await loadMarketplaces();
      }
      if (action === "delete") {
        if (!confirm(`Delete "${mp.name}" and all its categories?`)) return;
        await api(`/admin/marketplaces/${id}`, { method: "DELETE" });
        toast("Marketplace deleted");
        await loadMarketplaces();
      }
    } catch (err) {
      toast(err.message, true);
    }
  };

  $("#category-marketplace-select").onchange = () =>
    loadCategories().catch((e) => toast(e.message, true));
  $("#category-show-hidden").onchange = () =>
    loadCategories().catch((e) => toast(e.message, true));
  $("#create-category-btn").onclick = () => openCategoryDialog();
  $("#category-form").onsubmit = saveCategory;

  $("#category-list").onclick = async (event) => {
    const btn = event.target.closest("button[data-cat-action]");
    if (!btn) return;
    const marketplaceId = $("#category-marketplace-select").value;
    const id = btn.dataset.id;
    const cat = state.categories.find((c) => c.id === id);
    const action = btn.dataset.catAction;
    try {
      if (action === "edit") openCategoryDialog(cat);
      if (action === "toggle") {
        const path = cat.is_active ? "hide" : "unhide";
        await api(`/admin/marketplaces/${marketplaceId}/categories/${id}/${path}`, { method: "POST" });
        toast(cat.is_active ? "Category hidden" : "Category activated");
        await loadCategories();
      }
      if (action === "delete") {
        if (!confirm(`Delete category "${cat.name}"?`)) return;
        await api(`/admin/marketplaces/${marketplaceId}/categories/${id}`, { method: "DELETE" });
        toast("Category deleted");
        await loadCategories();
        await loadMarketplaces();
      }
    } catch (err) {
      toast(err.message, true);
    }
  };

  $$("[data-close-dialog]").forEach((btn) => {
    btn.onclick = () => btn.closest("dialog")?.close();
  });

  const mpForm = $("#marketplace-form");
  mpForm.elements.name.oninput = () => {
    if (!state.editingMarketplaceId && !mpForm.elements.slug.dataset.touched) {
      mpForm.elements.slug.value = slugify(mpForm.elements.name.value);
    }
  };
  mpForm.elements.slug.oninput = () => {
    mpForm.elements.slug.dataset.touched = "1";
  };
}

function debounce(fn, ms) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}

async function bootstrapApp() {
  renderAdminBuildStamp();
  try {
    const me = await api("/auth/me");
    state.staffRole = me.role || "";
    $("#admin-email").textContent = me.email || "";
    $("#users-role-stat").textContent = roleLabel(state.staffRole);
    await loadMarketplaces();
    await loadCategoryMarketplaceOptions();
  } catch (err) {
    toast(err.message, true);
    logout();
  }
}

document.addEventListener("DOMContentLoaded", () => {
  bindEvents();
  buildOpeningHoursFields();
  if (state.token) {
    showScreen("app");
    bootstrapApp();
  } else {
    showScreen("login");
  }
});
