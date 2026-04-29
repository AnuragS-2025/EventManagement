function toggleAuth() {
    document.getElementById('loginBox').classList.toggle('hidden');
    document.getElementById('registerBox').classList.toggle('hidden');
}

document.getElementById('loginForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;

    try {
        const response = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });
        
        const data = await response.json();
        if (response.ok) {
            localStorage.setItem('token', data.token);
            localStorage.setItem('user', JSON.stringify(data.user));
            window.location.href = data.user.role === 'admin' ? 'admin.html' : 'index.html';
        } else {
            showMessage('loginAlert', data.message || 'Login failed', 'error');
        }
    } catch (error) {
        showMessage('loginAlert', 'Network Error', 'error');
    }
});

document.getElementById('registerForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = document.getElementById('regName').value;
    const email = document.getElementById('regEmail').value;
    const password = document.getElementById('regPassword').value;
    const role = document.getElementById('regRole').value;

    try {
        const response = await fetch(`${API_URL}/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, email, password, role })
        });
        
        const data = await response.json();
        if (response.ok) {
            showMessage('registerAlert', 'Registration successful! Please login.', 'success');
            setTimeout(toggleAuth, 1500);
        } else {
            showMessage('registerAlert', data.message || 'Registration failed', 'error');
        }
    } catch (error) {
        showMessage('registerAlert', 'Network Error', 'error');
    }
});
