/* MarGem Admin — marketplace & category management */

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
};

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => [...document.querySelectorAll(sel)];

function apiBase() {
  const configured = (window.MARGEM_API_URL || "").trim();
  if (configured) return configured.replace(/\/$/, "");
  return window.location.origin;
}

function authHeaders() {
  return {
    Authorization: `Bearer ${state.token}`,
    "Content-Type": "application/json",
  };
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
  sessionStorage.removeItem(TOKEN_KEY);
  showScreen("login");
}

function switchView(view) {
  $$(".tab").forEach((tab) => tab.classList.toggle("active", tab.dataset.view === view));
  $("#view-marketplaces").classList.toggle("hidden", view !== "marketplaces");
  $("#view-categories").classList.toggle("hidden", view !== "categories");
  $("#view-users").classList.toggle("hidden", view !== "users");
  if (view === "categories") loadCategoryMarketplaceOptions();
  if (view === "users") loadUsers().catch((e) => toast(e.message, true));
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

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
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
          <img class="mp-logo" src="${mp.logo_image_url || "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='44' height='44'%3E%3Crect fill='%23f3ebe2' width='44' height='44' rx='12'/%3E%3C/svg%3E"}" alt="" />
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

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
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
    ${mp.cover_image_url ? `<img class="preview-cover" src="${mp.cover_image_url}" alt="" />` : ""}
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

function bindEvents() {
  $("#login-form").onsubmit = async (event) => {
    event.preventDefault();
    const email = $("#login-email").value.trim();
    const password = $("#login-password").value;
    try {
      const res = await fetch(`${apiBase()}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        throw new Error(formatApiError(data.detail, "Login failed"));
      }
      state.token = data.access_token;
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
      showScreen("app");
      await bootstrapApp();
    } catch (err) {
      logout();
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
