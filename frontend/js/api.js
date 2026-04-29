const API_URL = 'http://localhost:5000/api';

function getToken() {
    return localStorage.getItem('token');
}

function getUser() {
    const userStr = localStorage.getItem('user');
    if (!userStr) return null;
    try {
        return JSON.parse(userStr);
    } catch (e) {
        return null;
    }
}

function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    window.location.href = 'login.html';
}

function requireAuth() {
    const user = getUser();
    if (!user) {
        window.location.href = 'login.html';
    }
    return user;
}

function showMessage(elementId, message, type) {
    const el = document.getElementById(elementId);
    if (el) {
        el.textContent = message;
        el.className = `alert alert-${type}`;
        el.style.display = 'block';
        setTimeout(() => { el.style.display = 'none'; }, 5000);
    }
}

// Global Headers Setup
function getHeaders() {
    const headers = { 'Content-Type': 'application/json' };
    const token = getToken();
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
}

// Global Toast Notification
function showToast(message, type = 'info') {
    let container = document.getElementById('toastContainer');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toastContainer';
        container.className = 'toast-container';
        document.body.appendChild(container);
    }

    const icons = { success: '✅', error: '❌', info: 'ℹ️', warning: '⚠️' };
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `<span class="toast-icon">${icons[type] || 'ℹ️'}</span><span>${message}</span>`;
    container.appendChild(toast);
    setTimeout(() => {
        toast.style.animation = 'toastOut 0.4s ease forwards';
        setTimeout(() => toast.remove(), 400);
    }, 4000);
}

// Global Custom Confirmation Modal
function confirmAction({ title, message, icon = '❓', confirmText = 'Confirm', cancelText = 'Cancel', onConfirm }) {
    const modalId = 'globalConfirmModal';
    let modal = document.getElementById(modalId);
    
    if (!modal) {
        modal = document.createElement('div');
        modal.id = modalId;
        modal.className = 'modal';
        document.body.appendChild(modal);
    }

    modal.innerHTML = `
        <div class="glass modal-content confirm-modal">
            <div class="confirm-icon">${icon}</div>
            <h3>${title}</h3>
            <p style="color: var(--text-muted); margin-top: 0.5rem;">${message}</p>
            <div class="confirm-buttons">
                <button class="btn-outline" id="confirmCancel">${cancelText}</button>
                <button class="btn" id="confirmOk">${confirmText}</button>
            </div>
        </div>
    `;

    modal.classList.add('active');

    const handleConfirm = () => {
        modal.classList.remove('active');
        if (onConfirm) onConfirm();
        cleanup();
    };

    const handleCancel = () => {
        modal.classList.remove('active');
        cleanup();
    };

    const cleanup = () => {
        document.getElementById('confirmOk').removeEventListener('click', handleConfirm);
        document.getElementById('confirmCancel').removeEventListener('click', handleCancel);
    };

    document.getElementById('confirmOk').addEventListener('click', handleConfirm);
    document.getElementById('confirmCancel').addEventListener('click', handleCancel);
}

// Generate Navbar UI
document.addEventListener('DOMContentLoaded', () => {
    const navRight = document.getElementById('nav-right');
    const user = getUser();

    if (navRight) {
        if (user) {
            let html = `<span>Hi, ${user.name}</span>`;
            
            html += `<button onclick="openProfileModal()" class="btn-outline" style="padding: 0.4rem 0.9rem; font-size: 0.85rem;">👤 Profile</button>`;

            // My Bookings link for customers
            if (user.role !== 'admin') {
                html += `<a href="mybookings.html" class="btn-outline" style="padding: 0.4rem 0.9rem; font-size: 0.85rem; text-decoration: none;">🎫 My Bookings</a>`;
            }
            
            // Dashboard link for admins
            if (user.role === 'admin') {
                html += `<a href="admin.html" class="btn-outline" style="padding: 0.4rem 0.9rem; font-size: 0.85rem; text-decoration: none; color: var(--accent);">⚡ Dashboard</a>`;
            }
            
            html += `<button onclick="logout()" class="btn-outline" style="padding: 0.4rem 0.9rem; font-size: 0.85rem;">Logout</button>`;
            navRight.innerHTML = html;
        } else {
            navRight.innerHTML = `<a href="login.html" class="btn" style="padding: 0.5rem 1.2rem; font-size: 0.9rem; text-decoration: none;">Sign In</a>`;
        }
    }
});

function openProfileModal() {
    const user = getUser();
    if (!user) return;

    const modalId = 'profileModal';
    let modal = document.getElementById(modalId);
    
    if (!modal) {
        modal = document.createElement('div');
        modal.id = modalId;
        modal.className = 'modal';
        document.body.appendChild(modal);
    }

    modal.innerHTML = `
        <div class="glass modal-content" style="max-width: 400px; text-align: center; padding: 3rem 2rem;">
            <div style="width: 80px; height: 80px; background: var(--accent); color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 2rem; margin: 0 auto 1.5rem; font-weight: 700;">
                ${user.name.charAt(0).toUpperCase()}
            </div>
            <h2 style="margin-bottom: 0.5rem;">${user.name}</h2>
            <p style="color: var(--text-dim); margin-bottom: 2rem;">${user.email}</p>
            
            <div style="background: var(--surface); padding: 1.5rem; border-radius: 12px; margin-bottom: 2rem; border: 1px solid var(--glass-border);">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-size: 0.9rem; color: var(--text-muted);">Account Type</span>
                    <span class="badge ${user.role === 'admin' ? 'paid' : 'pending'}" style="text-transform: capitalize;">${user.role}</span>
                </div>
            </div>

            <div style="display: flex; gap: 1rem;">
                <button class="btn-outline" style="flex: 1;" onclick="document.getElementById('profileModal').classList.remove('active')">Close</button>
                <button class="btn" style="flex: 1;" onclick="logout()">Logout</button>
            </div>
        </div>
    `;

    modal.classList.add('active');
}

