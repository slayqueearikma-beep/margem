const state = {
  apiBase: localStorage.getItem('margem_admin_api') || '',
  token: localStorage.getItem('margem_admin_token') || '',
  selectedId: null,
};

const $ = (id) => document.getElementById(id);

function apiUrl(path) {
  const base = state.apiBase.replace(/\/$/, '');
  return `${base}${path}`;
}

function headers() {
  return {
    Authorization: `Bearer ${state.token}`,
    'Content-Type': 'application/json',
  };
}

function showAlert(msg) {
  const el = $('alert');
  el.textContent = msg;
  el.classList.remove('hidden');
}

async function api(path, options = {}) {
  const res = await fetch(apiUrl(path), {
    ...options,
    headers: { ...headers(), ...(options.headers || {}) },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || res.statusText);
  }
  if (res.status === 204) return null;
  return res.json();
}

function statusBadge(status) {
  return `<span class="badge ${status}">${status}</span>`;
}

async function loadPartnerships() {
  const status = $('statusFilter').value;
  const qs = status ? `?status=${status}` : '';
  const items = await api(`/admin/partnerships${qs}`);
  const list = $('partnershipList');
  list.innerHTML = items
    .map(
      (p) => `
    <div class="item ${state.selectedId === p.id ? 'selected' : ''}" data-id="${p.id}">
      <strong>${p.name}</strong> ${statusBadge(p.status)}
      <div style="color:#8e8e93;font-size:13px;margin-top:4px">
        ${p.partnership_type.replace(/_/g, ' ')} · ${p.member_count} members
        ${p.is_verified ? ' · ✓ verified' : ''}
      </div>
    </div>`
    )
    .join('');
  list.querySelectorAll('.item').forEach((el) => {
    el.addEventListener('click', () => selectPartnership(el.dataset.id));
  });
}

async function selectPartnership(id) {
  state.selectedId = id;
  await loadPartnerships();
  const detail = await api(`/admin/partnerships/${id}`);
  $('detailTitle').textContent = detail.name;
  $('partnershipDetail').innerHTML = `
    <dl>
      <dt>Status</dt><dd>${statusBadge(detail.status)}</dd>
      <dt>Type</dt><dd>${detail.partnership_type}</dd>
      <dt>Marketplace</dt><dd>${detail.marketplace_slug || 'Any'}</dd>
      <dt>Members</dt><dd>${detail.member_count}</dd>
      <dt>Trust score</dt><dd>${detail.joint_trust_score}★</dd>
      <dt>Collaborations</dt><dd>${detail.successful_collaborations}</dd>
      <dt>Description</dt><dd>${detail.description || '—'}</dd>
    </dl>
    <h4>Team</h4>
    <ul>${detail.members.map((m) => `<li>${m.business_name} (${m.role})</li>`).join('')}</ul>
  `;
  $('detailActions').classList.remove('hidden');

  const audit = await api(`/admin/partnerships/${id}/audit-log`);
  $('auditLog').innerHTML = audit
    .map((e) => `<div class="item"><strong>${e.action}</strong><br/><small>${e.created_at}</small></div>`)
    .join('') || '<div class="empty">No audit entries</div>';

  const revenue = await api(`/admin/partnerships/${id}/revenue-records`);
  $('revenueRecords').innerHTML = revenue
    .map(
      (r) =>
        `<div class="item">${r.total_amount_mad} MAD · ${r.created_at}<br/><small>${JSON.stringify(r.allocations)}</small></div>`
    )
    .join('') || '<div class="empty">No revenue records</div>';
}

$('saveAuth').addEventListener('click', () => {
  state.apiBase = $('apiBase').value.trim();
  state.token = $('token').value.trim();
  localStorage.setItem('margem_admin_api', state.apiBase);
  localStorage.setItem('margem_admin_token', state.token);
  loadPartnerships().catch((e) => showAlert(e.message));
});

$('refreshBtn').addEventListener('click', () => {
  loadPartnerships().catch((e) => showAlert(e.message));
});

$('statusFilter').addEventListener('change', () => {
  loadPartnerships().catch((e) => showAlert(e.message));
});

$('approveBtn').addEventListener('click', async () => {
  if (!state.selectedId) return;
  await api(`/admin/partnerships/${state.selectedId}/approve`, { method: 'POST' });
  await selectPartnership(state.selectedId);
});

$('suspendBtn').addEventListener('click', async () => {
  if (!state.selectedId) return;
  await api(`/admin/partnerships/${state.selectedId}/suspend`, { method: 'POST' });
  await selectPartnership(state.selectedId);
});

$('reactivateBtn').addEventListener('click', async () => {
  if (!state.selectedId) return;
  await api(`/admin/partnerships/${state.selectedId}/reactivate`, { method: 'POST' });
  await selectPartnership(state.selectedId);
});

$('apiBase').value = state.apiBase;
$('token').value = state.token;
if (state.token) {
  loadPartnerships().catch((e) => showAlert(e.message));
}
