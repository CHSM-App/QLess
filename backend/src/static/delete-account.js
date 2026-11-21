// Moved out of delete-account.html so the Content-Security-Policy can forbid inline scripts.
  function showSnackbar() {
    const sb = document.getElementById('snackbar');
    sb.classList.add('show');
    setTimeout(() => sb.classList.remove('show'), 5000);
  }

  document.getElementById('deleteForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    const btn = document.getElementById('submitBtn');
    btn.disabled = true;
    btn.textContent = 'Submitting...';

    const data = {
      name: document.getElementById('name').value,
      phone: document.getElementById('phone').value,
      userType: document.getElementById('userType').value,
      reason: document.getElementById('reason').value,
    };

    document.getElementById('deleteForm').style.display = 'none';
    document.getElementById('successBox').style.display = 'block';
    showSnackbar();

    fetch('/delete-account/request', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    }).catch(() => {});
  });
