// ===== ADMIN DASHBOARD - admin.js =====

document.addEventListener('DOMContentLoaded', () => {
    const user = requireAuth();
    if (!user || user.role !== 'admin') {
        window.location.href = 'index.html';
        return;
    }
    loadAdminEvents();
    loadAllBookings();
});

async function seedDemoData() {
    confirmAction({
        title: '✨ Populate Demo Data?',
        message: 'This will add several sample events and bookings to showcase the analytics. This is great for first-time setup!',
        confirmText: 'Yes, Populate',
        onConfirm: async () => {
            try {
                const response = await fetch(`${API_URL}/demo`, {
                    method: 'GET',
                    headers: getHeaders()
                });
                
                if (response.ok) {
                    showToast('Demo data seeded successfully!', 'success');
                    loadAdminEvents();
                    loadAllBookings();
                } else {
                    showToast('Failed to seed demo data', 'error');
                }
            } catch (error) {
                showToast('Network error', 'error');
            }
        }
    });
}


let eventsData = [];
let allBookingsData = [];
let revenueChart = null;
let occupancyChart = null;
let statusChart = null;



// ===== DASHBOARD STATS =====
function updateDashboardStats() {
    const totalEvents = eventsData.length;
    const totalTicketsSold = eventsData.reduce((sum, e) => sum + Number(e.tickets_sold || 0), 0);
    const pendingBookings = allBookingsData.filter(b => b.booking_status === 'pending').length;
    const totalRevenue = allBookingsData.reduce((sum, b) => sum + Number(b.amount || 0), 0);

    animateCounter('statEvents', totalEvents);
    animateCounter('statTickets', totalTicketsSold);
    animateCounter('statPending', pendingBookings);
    
    const revenueEl = document.getElementById('statRevenue');
    if (revenueEl) {
        animateValue(revenueEl, 0, totalRevenue, 800, (v) => `₹${v.toLocaleString()}`);
    }

    // Refresh All Charts
    initRevenueChart();
    initOccupancyChart();
    initStatusChart();
}

function initRevenueChart() {
    const canvas = document.getElementById('revenueChart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    if (!allBookingsData.length) {
        if (revenueChart) revenueChart.destroy();
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#64748b';
        ctx.textAlign = 'center';
        ctx.font = '14px Inter';
        ctx.fillText('No booking data available yet', canvas.width / 2, canvas.height / 2);
        return;
    }

    const eventRevenue = {};
    allBookingsData.forEach(b => {
        const name = b.event_name || 'Event';
        eventRevenue[name] = (eventRevenue[name] || 0) + Number(b.amount || 0);
    });

    const entries = Object.entries(eventRevenue).sort((a, b) => b[1] - a[1]).slice(0, 8);
    
    if (revenueChart) revenueChart.destroy();
    revenueChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: entries.map(e => e[0]),
            datasets: [{
                label: 'Revenue Growth',
                data: entries.map(e => e[1]),
                fill: true,
                backgroundColor: 'rgba(139, 92, 246, 0.1)',
                borderColor: '#8b5cf6',
                borderWidth: 3,
                tension: 0.4,
                pointRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: { beginAtZero: true, grid: { color: 'rgba(255, 255, 255, 0.05)' }, ticks: { color: '#94a3b8', callback: (v) => '₹' + v } },
                x: { grid: { display: false }, ticks: { color: '#94a3b8', callback: function(val, index) { 
                    const label = this.getLabelForValue(val);
                    return label.length > 10 ? label.substr(0, 10) + '...' : label;
                }}}
            },
            plugins: {
                legend: { display: false },
                tooltip: { backgroundColor: '#1e293b', padding: 12, cornerRadius: 8 }
            }
        }
    });
}

function initOccupancyChart() {
    const canvas = document.getElementById('occupancyChart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');

    if (!eventsData.length) {
        if (occupancyChart) occupancyChart.destroy();
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#64748b';
        ctx.textAlign = 'center';
        ctx.font = '14px Inter';
        ctx.fillText('No events created yet', canvas.width / 2, canvas.height / 2);
        return;
    }

    const totalTickets = eventsData.reduce((sum, e) => sum + e.total_tickets, 0);
    const soldTickets = eventsData.reduce((sum, e) => sum + Number(e.tickets_sold || 0), 0);
    const remaining = Math.max(0, totalTickets - soldTickets);

    if (occupancyChart) occupancyChart.destroy();
    occupancyChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Sold', 'Remaining'],
            datasets: [{
                data: [soldTickets, remaining],
                backgroundColor: ['#8b5cf6', 'rgba(255, 255, 255, 0.05)'],
                borderColor: ['#8b5cf6', 'rgba(255, 255, 255, 0.1)'],
                borderWidth: 1,
                cutout: '75%'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'bottom', labels: { color: '#94a3b8', usePointStyle: true, padding: 20 } }
            }
        }
    });
}

function initStatusChart() {
    const canvas = document.getElementById('statusChart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');

    if (!allBookingsData.length) {
        if (statusChart) statusChart.destroy();
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#64748b';
        ctx.textAlign = 'center';
        ctx.font = '14px Inter';
        ctx.fillText('No bookings recorded yet', canvas.width / 2, canvas.height / 2);
        return;
    }

    const paid = allBookingsData.filter(b => b.booking_status === 'paid' || b.booking_status === 'confirmed').length;
    const pending = allBookingsData.filter(b => b.booking_status === 'pending').length;

    if (statusChart) statusChart.destroy();
    statusChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Confirmed / Paid', 'Pending Payment'],
            datasets: [{
                label: 'Bookings',
                data: [paid, pending],
                backgroundColor: ['#10b981', '#f59e0b'],
                borderRadius: 8,
                barThickness: 40
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: { beginAtZero: true, grid: { color: 'rgba(255, 255, 255, 0.05)' }, ticks: { color: '#94a3b8' } },
                y: { grid: { display: false }, ticks: { color: '#f8fafc', font: { weight: '600' } } }
            },
            plugins: {
                legend: { display: false }
            }
        }
    });
}


function animateCounter(elementId, target) {
    const el = document.getElementById(elementId);
    if (!el) return;
    animateValue(el, 0, target, 800, (v) => v.toLocaleString());
}

function animateValue(el, start, end, duration, formatter) {
    const range = end - start;
    if (range === 0) { el.textContent = formatter(end); return; }
    const startTime = performance.now();
    function update(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3); // ease out cubic
        const current = Math.round(start + range * eased);
        el.textContent = formatter(current);
        if (progress < 1) requestAnimationFrame(update);
    }
    requestAnimationFrame(update);
}

// ===== LOAD EVENTS =====
async function loadAdminEvents() {
    try {
        const response = await fetch(`${API_URL}/events`);
        const events = await response.json();
        eventsData = events;

        const tbody = document.getElementById('eventsTableBody');
        tbody.innerHTML = '';

        if (events.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-center">
                <div class="empty-state" style="padding: 2rem;">
                    <div class="empty-icon">📅</div>
                    <h3>No Events Yet</h3>
                    <p>Create your first event to get started.</p>
                </div>
            </td></tr>`;
            updateDashboardStats();
            return;
        }

        events.forEach((event, index) => {
            const sold = Number(event.tickets_sold || 0);
            const total = event.total_tickets;
            const percent = Math.round((sold / total) * 100);
            const isHigh = percent > 80;

            const tr = document.createElement('tr');
            tr.style.animationDelay = `${index * 0.05}s`;
            tr.innerHTML = `
                <td><strong style="color: var(--text);">${event.name}</strong></td>
                <td style="color: var(--text-muted);">${new Date(event.date).toLocaleDateString()} · ${event.time}</td>
                <td style="color: var(--text-muted);">${event.venue}</td>
                <td><strong>${sold}</strong> / ${total}</td>
                <td>
                    <div style="display: flex; align-items: center; gap: 0.5rem;">
                        <div class="availability-bar" style="width: 80px;">
                            <div class="fill ${isHigh ? 'low' : ''}" style="width: ${percent}%"></div>
                        </div>
                        <span style="font-size: 0.8rem; color: ${isHigh ? 'var(--warning)' : 'var(--text-muted)'};">${percent}%</span>
                    </div>
                </td>
                <td>
                    <div style="display: flex; gap: 0.4rem;">
                        <button class="btn-outline btn-sm" onclick="editEvent(${event.id})">✏️ Edit</button>
                        <button class="btn-danger btn-sm" onclick="deleteEvent(${event.id})">🗑️</button>
                    </div>
                </td>
            `;
            tbody.appendChild(tr);
        });

        updateDashboardStats();
    } catch (error) {
        console.error('Error loading events:', error);
        document.getElementById('eventsTableBody').innerHTML = `<tr><td colspan="6" class="text-center" style="color:var(--danger)">Failed to load events.</td></tr>`;
    }
}

// ===== LOAD BOOKINGS =====
async function loadAllBookings() {
    try {
        const response = await fetch(`${API_URL}/bookings/all`, {
            headers: getHeaders()
        });

        if (!response.ok) throw new Error('Failed to fetch bookings');

        allBookingsData = await response.json();
        renderBookings();
        updateDashboardStats();
    } catch (error) {
        console.error('Error loading bookings:', error);
        document.getElementById('bookingsTableBody').innerHTML = `<tr><td colspan="8" class="text-center" style="color:var(--danger)">Failed to load bookings.</td></tr>`;
    }
}

// ===== FILTER & SORT BOOKINGS =====
function handleBookingFilterSort() {
    renderBookings();
}

function renderBookings() {
    let filtered = [...allBookingsData];

    const filterCustomer = document.getElementById('filterCustomer').value.toLowerCase();
    const filterEvent = document.getElementById('filterEvent').value.toLowerCase();
    const filterStatus = document.getElementById('filterStatus')?.value || '';
    const sortVal = document.getElementById('sortBookings').value;

    if (filterCustomer) {
        filtered = filtered.filter(b =>
            b.customer_name.toLowerCase().includes(filterCustomer) ||
            b.customer_email.toLowerCase().includes(filterCustomer)
        );
    }

    if (filterEvent) {
        filtered = filtered.filter(b => b.event_name.toLowerCase().includes(filterEvent));
    }

    if (filterStatus) {
        filtered = filtered.filter(b => b.booking_status === filterStatus);
    }

    if (sortVal === 'date_asc') {
        filtered.sort((a, b) => new Date(a.booking_date) - new Date(b.booking_date));
    } else if (sortVal === 'tickets_desc') {
        filtered.sort((a, b) => b.tickets_booked - a.tickets_booked);
    } else {
        filtered.sort((a, b) => new Date(b.booking_date) - new Date(a.booking_date));
    }

    // Update count
    const countEl = document.getElementById('bookingCount');
    if (countEl) countEl.textContent = `${filtered.length} booking${filtered.length !== 1 ? 's' : ''}`;

    const tbody = document.getElementById('bookingsTableBody');
    tbody.innerHTML = '';

    if (filtered.length === 0) {
        tbody.innerHTML = `<tr><td colspan="8" class="text-center">
            <div class="empty-state" style="padding: 2rem;">
                <div class="empty-icon">📋</div>
                <h3>No Bookings Found</h3>
                <p>No bookings match your current filters.</p>
            </div>
        </td></tr>`;
        return;
    }

    filtered.forEach((booking, index) => {
        const tr = document.createElement('tr');
        tr.style.animationDelay = `${index * 0.03}s`;
        const date = new Date(booking.booking_date).toLocaleString();

        const isPaid = booking.booking_status === 'paid' || booking.booking_status === 'confirmed';
        const statusClass = isPaid ? 'paid' : 'pending';
        const statusText = isPaid ? 'Paid' : 'Pending';

        const amount = Number(booking.amount || 0).toFixed(2);

        let actionBtn = '';
        if (booking.booking_status === 'pending') {
            actionBtn = `<button class="btn-success btn-sm" onclick="markBookingPaid(${booking.booking_id})">💰 Mark Paid</button>`;
        } else {
            actionBtn = `<span class="badge paid" style="font-size: 0.72rem;">✓ Complete</span>`;
        }

        const bookingImageUrl = getEventImage(booking.event_name, '', booking.image_url);

        tr.innerHTML = `
            <td style="font-weight: 600; color: var(--text-muted);">#${booking.booking_id}</td>
            <td>
                <div style="display: flex; align-items: center; gap: 0.8rem;">
                    <img src="${bookingImageUrl}" style="width: 40px; height: 40px; border-radius: 6px; object-fit: cover; border: 1px solid var(--glass-border);">
                    <div style="font-weight: 600;">${booking.event_name}</div>
                </div>
            </td>
            <td>
                <div>
                    <strong style="font-size: 0.9rem;">${booking.customer_name}</strong>
                    <div style="font-size: 0.78rem; color: var(--text-dim);">${booking.customer_email}</div>
                </div>
            </td>
            <td style="text-align: center; font-weight: 700;">${booking.tickets_booked}</td>
            <td style="font-weight: 700; color: var(--success);">₹${amount}</td>
            <td><span class="badge ${statusClass}">${statusText}</span></td>
            <td style="font-size: 0.82rem; color: var(--text-dim);">${date}</td>
            <td>${actionBtn}</td>
        `;
        tbody.appendChild(tr);
    });
}

function getEventImage(name, desc, manualUrl) {
    if (manualUrl) return manualUrl;
    const keywords = ['music', 'concert', 'party', 'tech', 'conference', 'meeting', 'food', 'festival', 'art', 'business', 'sports', 'coding'];
    const lowerText = `${name} ${desc || ''}`.toLowerCase();
    const found = keywords.find(k => lowerText.includes(k)) || 'event';
    return `https://loremflickr.com/800/450/${found}`;
}

// ===== MARK AS PAID =====
async function markBookingPaid(bookingId) {
    confirmAction({
        title: 'Confirm Payment',
        message: `Are you sure you want to mark booking #${bookingId} as paid? This will confirm the receipt of funds at the venue.`,
        icon: '💰',
        confirmText: 'Mark as Paid',
        onConfirm: async () => {
            try {
                const response = await fetch(`${API_URL}/bookings/${bookingId}/mark-paid`, {
                    method: 'PUT',
                    headers: getHeaders()
                });

                if (response.ok) {
                    showToast(`Booking #${bookingId} marked as paid!`, 'success');
                    loadAllBookings();
                } else {
                    const data = await response.json();
                    showToast(data.message || 'Failed to mark as paid', 'error');
                }
            } catch (error) {
                showToast('Network Error', 'error');
            }
        }
    });
}

// ===== EVENT MODAL =====
function openEventModal() {
    document.getElementById('eventForm').reset();
    document.getElementById('eventId').value = '';
    document.getElementById('modalTitle').textContent = '✨ Create New Event';
    document.getElementById('eventModal').classList.add('active');
}

function closeEventModal() {
    document.getElementById('eventModal').classList.remove('active');
    const alert = document.getElementById('modalAlert');
    if (alert) alert.style.display = 'none';
}

function editEvent(id) {
    const event = eventsData.find(e => e.id === id);
    if (!event) return;

    document.getElementById('eventId').value = event.id;
    document.getElementById('eventName').value = event.name;
    document.getElementById('eventDesc').value = event.description;

    const isodate = new Date(event.date).toISOString().split('T')[0];
    document.getElementById('eventDate').value = isodate;

    document.getElementById('eventTime').value = event.time;
    document.getElementById('eventVenue').value = event.venue;
    document.getElementById('eventTickets').value = event.total_tickets;
    
    const priceField = document.getElementById('eventPrice');
    if (priceField) priceField.value = event.ticket_price || '';

    const categoryField = document.getElementById('eventCategory');
    if (categoryField) categoryField.value = event.category || 'General';

    const imageField = document.getElementById('eventImageUrl');
    if (imageField) imageField.value = event.image_url || '';

    document.getElementById('modalTitle').textContent = '✏️ Edit Event';
    document.getElementById('eventModal').classList.add('active');
}

// ===== DELETE EVENT =====
async function deleteEvent(id) {
    confirmAction({
        title: 'Delete Event',
        message: 'Are you sure you want to delete this event? This will permanently remove all associated bookings and revenue records.',
        icon: '🗑️',
        confirmText: 'Delete Permanently',
        onConfirm: async () => {
            try {
                const response = await fetch(`${API_URL}/events/${id}`, {
                    method: 'DELETE',
                    headers: getHeaders()
                });

                if (response.ok) {
                    showToast('Event deleted successfully', 'success');
                    loadAdminEvents();
                    loadAllBookings();
                } else {
                    const data = await response.json();
                    showToast(data.message || 'Delete failed', 'error');
                }
            } catch (error) {
                showToast('Network Error', 'error');
            }
        }
    });
}

// ===== EVENT FORM SUBMIT =====
document.getElementById('eventForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();

    const id = document.getElementById('eventId').value;
    const isEdit = id !== '';

    const payload = {
        name: document.getElementById('eventName').value,
        description: document.getElementById('eventDesc').value,
        date: document.getElementById('eventDate').value,
        time: document.getElementById('eventTime').value,
        venue: document.getElementById('eventVenue').value,
        total_tickets: parseInt(document.getElementById('eventTickets').value),
        ticket_price: parseFloat(document.getElementById('eventPrice')?.value) || 50,
        category: document.getElementById('eventCategory')?.value || 'General',
        image_url: document.getElementById('eventImageUrl')?.value || null
    };

    const btn = e.target.querySelector('button[type="submit"]');
    const originalText = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '⏳ Saving...';

    try {
        const url = isEdit ? `${API_URL}/events/${id}` : `${API_URL}/events`;
        const method = isEdit ? 'PUT' : 'POST';

        const response = await fetch(url, {
            method: method,
            headers: getHeaders(),
            body: JSON.stringify(payload)
        });

        const data = await response.json();
        btn.disabled = false;
        btn.innerHTML = originalText;

        if (response.ok) {
            closeEventModal();
            showToast(`Event ${isEdit ? 'updated' : 'created'} successfully!`, 'success');
            showMessage('statusMessage', `Event ${isEdit ? 'updated' : 'created'} successfully!`, 'success');
            loadAdminEvents();
        } else {
            showMessage('modalAlert', data.message || 'Operation failed', 'error');
        }
    } catch (error) {
        btn.disabled = false;
        btn.innerHTML = originalText;
        showMessage('modalAlert', 'Network Error', 'error');
    }
});
