let allEvents = [];
let currentCategory = 'All';
let currentEventTicketPrice = 0;
let currentBookingId = null;

document.addEventListener('DOMContentLoaded', loadEvents);

// ===== LOAD EVENTS =====
async function loadEvents() {
    const skeletonGrid = document.getElementById('skeletonGrid');
    const eventsGrid = document.getElementById('eventsGrid');

    try {
        const response = await fetch(`${API_URL}/events`);
        const events = await response.json();
        allEvents = events;

        // Hide skeleton, show grid
        if (skeletonGrid) skeletonGrid.classList.add('hidden');
        eventsGrid.classList.remove('hidden');
        
        renderEvents(events);
    } catch (error) {
        console.error('Error loading events:', error);
        if (skeletonGrid) skeletonGrid.classList.add('hidden');
        eventsGrid.classList.remove('hidden');
        eventsGrid.innerHTML = `
            <div class="empty-state" style="grid-column: 1 / -1;">
                <div class="empty-icon">⚠️</div>
                <h3>Connection Error</h3>
                <p>Failed to load events. Please check if the server is running.</p>
                <button class="btn" style="margin-top: 1rem;" onclick="loadEvents()">↻ Retry</button>
            </div>`;
    }
}

function getEventImage(name, desc, manualUrl) {
    if (manualUrl) return manualUrl;
    const keywords = ['music', 'concert', 'party', 'tech', 'conference', 'meeting', 'food', 'festival', 'art', 'business', 'sports', 'coding'];
    const lowerText = `${name} ${desc || ''}`.toLowerCase();
    const found = keywords.find(k => lowerText.includes(k)) || 'event';
    return `https://loremflickr.com/800/450/${found}`;
}

// ===== RENDER EVENTS =====
function renderEvents(events) {
    const grid = document.getElementById('eventsGrid');
    grid.innerHTML = '';

    if (events.length === 0) {
        grid.innerHTML = `
            <div class="empty-state" style="grid-column: 1 / -1;">
                <div class="empty-icon">🎭</div>
                <h3>No Events Found</h3>
                <p>There are no upcoming events matching your search criteria. Try a different filter!</p>
            </div>`;
        return;
    }

    events.forEach((event, index) => {
        const available = event.total_tickets - (event.tickets_sold || 0);
        const ticketPrice = Number(parseFloat(event.ticket_price) || 50).toFixed(2);
        const soldPercent = Math.round(((event.tickets_sold || 0) / event.total_tickets) * 100);
        const isLow = available > 0 && available <= Math.ceil(event.total_tickets * 0.2);
        const isPopular = (event.tickets_sold || 0) >= Math.ceil(event.total_tickets * 0.5);
        const isSoldOut = available <= 0;

        const eventDate = new Date(event.date);
        const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        const dateStr = `${monthNames[eventDate.getMonth()]} ${eventDate.getDate()}, ${eventDate.getFullYear()}`;
        
        const imageUrl = getEventImage(event.name, event.description, event.image_url);
        
        const card = document.createElement('div');
        card.className = 'glass event-card';
        card.style.animationDelay = `${index * 0.08}s`;
        
        card.innerHTML = `
            <div class="event-image">
                <img src="${imageUrl}" alt="${event.name}" loading="lazy">
                <div style="position: absolute; top: 1rem; right: 1rem; background: rgba(0,0,0,0.6); backdrop-filter: blur(4px); padding: 4px 10px; border-radius: 20px; font-size: 0.7rem; font-weight: 600; color: white; border: 1px solid rgba(255,255,255,0.1);">
                    ${event.category || 'General'}
                </div>
            </div>
            <div class="card-header">
                <div>
                    ${isPopular ? '<span style="background: var(--accent-glow); color: var(--accent); padding: 2px 8px; border-radius: 4px; font-size: 0.7rem; font-weight: 700; text-transform: uppercase; margin-bottom: 0.5rem; display: inline-block;">🔥 Popular</span>' : ''}
                    <h3>${event.name}</h3>
                </div>
                <span class="date-badge">${dateStr}</span>
            </div>
            <div class="card-info">
                <span>📍 ${event.venue}</span>
                <span>🕐 ${event.time}</span>
            </div>
            <div class="desc">${event.description}</div>
            <div class="card-footer">
                <div class="ticket-info">
                    <div class="ticket-count">
                        <strong>${available}</strong> / ${event.total_tickets} left
                        ${isLow ? '<span style="color: var(--warning); font-size: 0.78rem; margin-left: 0.3rem;">⚡ Selling fast</span>' : ''}
                    </div>
                    <div class="ticket-price">₹${ticketPrice}</div>
                </div>
                <div class="availability-bar">
                    <div class="fill ${soldPercent > 80 ? 'low' : ''}" style="width: ${soldPercent}%"></div>
                </div>
                <button class="btn" style="width: 100%; mt-2" 
                    onclick="openBookingModal(${event.id}, '${event.name.replace(/'/g, "\\'")}', ${available}, ${ticketPrice})" 
                    ${isSoldOut ? 'disabled' : ''}>
                    ${isSoldOut ? '🚫 Sold Out' : '🎫 Book Tickets'}
                </button>
            </div>
        `;
        grid.appendChild(card);
    });
}

// ===== CATEGORY FILTER =====
function setCategoryFilter(cat) {
    currentCategory = cat;
    
    // Update pills UI
    const pills = document.querySelectorAll('.pill');
    pills.forEach(p => {
        if (p.textContent.includes(cat) || (cat === 'All' && p.textContent === 'All')) {
            p.classList.add('active');
        } else {
            p.classList.remove('active');
        }
    });

    handleFilterSort();
}

// ===== SEARCH / FILTER / SORT =====
function handleFilterSort() {
    const query = document.getElementById('eventSearch').value.toLowerCase().trim();
    const sortBy = document.getElementById('eventSort').value;
    
    let filtered = [...allEvents];
    
    // Category filter
    if (currentCategory !== 'All') {
        filtered = filtered.filter(e => e.category === currentCategory);
    }
    
    // Search filter
    if (query) {
        filtered = filtered.filter(e =>
            e.name.toLowerCase().includes(query) ||
            e.venue.toLowerCase().includes(query) ||
            (e.description && e.description.toLowerCase().includes(query))
        );
    }
    
    // Sorting
    switch(sortBy) {
        case 'date_asc':
            filtered.sort((a, b) => new Date(a.date) - new Date(b.date));
            break;
        case 'date_desc':
            filtered.sort((a, b) => new Date(b.date) - new Date(a.date));
            break;
        case 'price_asc':
            filtered.sort((a, b) => parseFloat(a.ticket_price) - parseFloat(b.ticket_price));
            break;
        case 'price_desc':
            filtered.sort((a, b) => parseFloat(b.ticket_price) - parseFloat(a.ticket_price));
            break;
        case 'popular':
            filtered.sort((a, b) => (b.tickets_sold || 0) - (a.tickets_sold || 0));
            break;
    }
    
    renderEvents(filtered);
}

// ===== BOOKING MODAL =====
function openBookingModal(id, name, available, ticketPrice) {
    const user = getUser();
    if (!user) {
        showToast('Please sign in to book tickets.', 'info');
        setTimeout(() => { window.location.href = 'login.html'; }, 1200);
        return;
    }

    document.getElementById('bookEventId').value = id;
    document.getElementById('bookEventName').value = name;
    document.getElementById('bookTicketPrice').value = ticketPrice;
    document.getElementById('bookQuantity').value = 1;
    document.getElementById('bookQuantity').setAttribute('max', available);
    document.getElementById('availableText').textContent = `${available} tickets available`;
    
    currentEventTicketPrice = Number(ticketPrice) || 50;
    updatePriceSummary();

    document.getElementById('bookingModal').classList.add('active');
}

function closeBookingModal() {
    document.getElementById('bookingModal').classList.remove('active');
    const alert = document.getElementById('bookingAlert');
    if (alert) alert.style.display = 'none';
}

// ===== TICKET COUNTER =====
function adjustQuantity(delta) {
    const input = document.getElementById('bookQuantity');
    const max = parseInt(input.getAttribute('max')) || 10;
    let val = parseInt(input.value) || 1;
    val += delta;
    if (val < 1) val = 1;
    if (val > max) val = max;
    input.value = val;
    updatePriceSummary();
}

function updatePriceSummary() {
    const qty = parseInt(document.getElementById('bookQuantity').value) || 1;
    const price = currentEventTicketPrice;
    const total = qty * price;

    document.getElementById('pricePerTicket').textContent = `₹${price.toFixed(2)}`;
    document.getElementById('priceQuantity').textContent = qty;
    document.getElementById('priceTotal').textContent = `₹${total.toFixed(2)}`;
}



// ===== BOOKING SUCCESS ANIMATION =====
function showBookingSuccess(bookingId, amount) {
    const overlay = document.createElement('div');
    overlay.className = 'success-overlay';
    overlay.innerHTML = `
        <div class="glass success-card">
            <div class="success-icon">🎉</div>
            <h3>Booking Confirmed!</h3>
            <p>Your booking <strong>#${bookingId}</strong> has been confirmed.<br>
            Total: <strong>₹${Number(amount).toFixed(2)}</strong> — Pay at the venue.</p>
            <button class="btn" onclick="this.closest('.success-overlay').remove()">
                Got It!
            </button>
        </div>
    `;
    document.body.appendChild(overlay);
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay) overlay.remove();
    });
}

// ===== FORM SUBMISSION =====
document.getElementById('bookingForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const event_id = Number(document.getElementById('bookEventId').value);
    const tickets_booked = Number(document.getElementById('bookQuantity').value);

    if (!event_id || isNaN(event_id) || !tickets_booked || isNaN(tickets_booked) || tickets_booked <= 0) {
        showMessage('bookingAlert', 'Please enter a valid ticket quantity.', 'error');
        return;
    }

    const btn = e.target.querySelector('button[type="submit"]');
    const originalText = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '<span style="animation: pulse-dot 1s infinite;">⏳</span> Processing...';

    const calculatedAmount = tickets_booked * currentEventTicketPrice;

    if (isNaN(calculatedAmount) || calculatedAmount <= 0) {
        showMessage('bookingAlert', 'Amount calculation error.', 'error');
        btn.disabled = false;
        btn.innerHTML = originalText;
        return;
    }

    try {
        const response = await fetch(`${API_URL}/bookings`, {
            method: 'POST',
            headers: getHeaders(),
            body: JSON.stringify({ event_id, tickets_booked, amount: calculatedAmount })
        });

        const data = await response.json();
        btn.disabled = false;
        btn.innerHTML = originalText;

        if (response.ok) {
            closeBookingModal();
            showBookingSuccess(data.booking_id, data.amount || calculatedAmount);
            showToast('Booking confirmed! Pay at the venue.', 'success');
            loadEvents();
        } else {
            showMessage('bookingAlert', data.message || 'Booking failed', 'error');
            showToast(data.message || 'Booking failed', 'error');
        }
    } catch (error) {
        btn.disabled = false;
        btn.innerHTML = originalText;
        showMessage('bookingAlert', 'Network Error', 'error');
        showToast('Network error. Please try again.', 'error');
    }
});
