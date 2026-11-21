// Moved out of admin-panel.html so the Content-Security-Policy can forbid inline scripts.
(function () {
  var TOKEN_KEY = 'qless_admin_token';

  var loginCard = document.getElementById('loginCard');
  var app = document.getElementById('app');
  var loginForm = document.getElementById('loginForm');
  var loginBtn = document.getElementById('loginBtn');
  var loginError = document.getElementById('loginError');
  var globalError = document.getElementById('globalError');
  var listEl = document.getElementById('list');
  var emptyEl = document.getElementById('empty');
  var logoutBtn = document.getElementById('logoutBtn');

  function token() { return localStorage.getItem(TOKEN_KEY); }
  function setToken(t) { localStorage.setItem(TOKEN_KEY, t); }
  function clearToken() { localStorage.removeItem(TOKEN_KEY); }

  function showApp() {
    loginCard.style.display = 'none';
    app.style.display = 'block';
    loadPending();
  }
  function showLogin() {
    clearToken();
    app.style.display = 'none';
    loginCard.style.display = 'block';
  }

  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
    });
  }

  function api(path, opts) {
    opts = opts || {};
    opts.headers = Object.assign({}, opts.headers, {
      'Authorization': 'Bearer ' + token(),
      'Content-Type': 'application/json',
    });
    return fetch('/admin' + path, opts).then(function (res) {
      if (res.status === 401 || res.status === 403) {
        showLogin();
        throw new Error('Session expired. Please sign in again.');
      }
      return res.json().then(function (body) {
        if (!res.ok) throw new Error(body.error || body.message || 'Request failed');
        return body;
      });
    });
  }

  function loadPending() {
    globalError.textContent = '';
    listEl.innerHTML = '';
    emptyEl.style.display = 'none';
    api('/doctors/pending').then(function (doctors) {
      if (!doctors.length) {
        emptyEl.style.display = 'block';
        return;
      }
      doctors.forEach(function (d) { listEl.appendChild(renderCard(d)); });
    }).catch(function (err) {
      globalError.textContent = err.message;
    });
  }

  function renderCard(d) {
    var card = document.createElement('div');
    card.className = 'card';
    card.innerHTML =
      '<h3>' + escapeHtml(d.name || 'Unnamed doctor') +
      '<span class="pill">#' + escapeHtml(d.doctor_id) + '</span></h3>' +
      '<div class="meta">' +
        '<div><b>Mobile:</b> ' + escapeHtml(d.mobile) + (d.email ? ' &middot; <b>Email:</b> ' + escapeHtml(d.email) : '') + '</div>' +
        '<div><b>Specialization:</b> ' + escapeHtml(d.specialization || '—') +
          (d.qualification ? ' &middot; ' + escapeHtml(d.qualification) : '') + '</div>' +
        '<div><b>License No:</b> ' + escapeHtml(d.license_no || '—') + '</div>' +
        '<div><b>Clinic:</b> ' + escapeHtml(d.clinic_name || '—') +
          (d.clinic_address ? ' — ' + escapeHtml(d.clinic_address) : '') + '</div>' +
      '</div>' +
      '<div class="actions">' +
        '<button class="btn-primary" data-action="verify">Approve</button>' +
        '<button class="btn-danger" data-action="reject">Reject</button>' +
      '</div>';

    card.querySelectorAll('button').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var action = btn.getAttribute('data-action');
        if (action === 'reject' && !confirm('Reject and remove ' + (d.name || 'this doctor') + '?')) return;

        card.querySelectorAll('button').forEach(function (b) { b.disabled = true; });
        api('/doctors/' + d.doctor_id + '/' + action, { method: 'POST' })
          .then(function () { card.remove(); if (!listEl.children.length) emptyEl.style.display = 'block'; })
          .catch(function (err) {
            globalError.textContent = err.message;
            card.querySelectorAll('button').forEach(function (b) { b.disabled = false; });
          });
      });
    });

    return card;
  }

  loginForm.addEventListener('submit', function (e) {
    e.preventDefault();
    loginError.textContent = '';
    loginBtn.disabled = true;
    fetch('/admin/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: document.getElementById('username').value.trim(),
        password: document.getElementById('password').value,
      }),
    }).then(function (res) {
      return res.json().then(function (body) { return { ok: res.ok, body: body }; });
    }).then(function (r) {
      if (!r.ok) throw new Error(r.body.error || 'Login failed');
      setToken(r.body.accessToken);
      showApp();
    }).catch(function (err) {
      loginError.textContent = err.message;
    }).finally(function () {
      loginBtn.disabled = false;
    });
  });

  logoutBtn.addEventListener('click', showLogin);

  if (token()) { showApp(); } else { showLogin(); }
})();
