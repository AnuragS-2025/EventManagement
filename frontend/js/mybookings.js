// ===== MY BOOKINGS - mybookings.js =====

document.addEventListener('DOMContentLoaded', () => {
    const user = requireAuth();
    if (!user) return;
    loadMyBookings();
});

function getEventImage(name, desc, manualUrl) {
    if (manualUrl) return manualUrl;
    const keywords = ['music', 'concert', 'party', 'tech', 'conference', 'meeting', 'food', 'festival', 'art', 'business', 'sports', 'coding'];
    const lowerText = `${name} ${desc || ''}`.toLowerCase();
    const found = keywords.find(k => lowerText.includes(k)) || 'event';
    return `https://loremflickr.com/800/450/${found}`;
}

async function loadMyBookings() {
    const container = document.getElementById('bookingsList');

    try {
        const response = await fetch(`${API_URL}/bookings/my-bookings`, {
            headers: getHeaders()
        });

        if (!response.ok) throw new Error('Failed to fetch bookings');

        const bookings = await response.json();
        container.innerHTML = '';

        if (bookings.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">🎫</div>
                    <h3>No Bookings Yet</h3>
                    <p>You haven't booked any events. Browse events and grab your tickets!</p>
                    <a href="index.html" class="btn" style="margin-top: 1rem;">Browse Events</a>
                </div>`;
            return;
        }

        bookings.forEach((booking, index) => {
            const card = document.createElement('div');
            card.className = 'glass booking-card';
            card.style.animationDelay = `${index * 0.08}s`;
            card.style.display = 'grid';
            card.style.gridTemplateColumns = '140px 1fr';
            card.style.gap = '1.5rem';
            card.style.padding = '1rem';

            const eventDate = new Date(booking.date);
            const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            const dateStr = `${monthNames[eventDate.getMonth()]} ${eventDate.getDate()}, ${eventDate.getFullYear()}`;
            const bookDate = new Date(booking.booking_date).toLocaleDateString();

            const isPaid = booking.status === 'paid' || booking.status === 'confirmed';
            const statusClass = isPaid ? 'paid' : 'pending';
            const statusText = isPaid ? 'Paid' : 'Pay at Venue';

            const imageUrl = getEventImage(booking.event_name, '', booking.image_url);

            let actionHtml = '';
            if (!isPaid) {
                actionHtml = `<button class="btn-danger btn-sm" onclick="cancelBooking(${booking.id})">Cancel</button>`;
            } else {
                actionHtml = `<button class="btn-outline btn-sm" onclick="viewTicket(${booking.id}, '${booking.event_name.replace(/'/g, "\\'")}', '${dateStr}', '${booking.time}', '${booking.venue}', ${booking.tickets_booked})">🎟️ View Ticket</button>`;
            }

            card.innerHTML = `
                <div style="height: 100%; border-radius: var(--radius-sm); overflow: hidden; position: relative;">
                    <img src="${imageUrl}" style="width: 100%; height: 100%; object-fit: cover;">
                    <div style="position: absolute; bottom: 0; left: 0; right: 0; background: rgba(0,0,0,0.6); backdrop-filter: blur(4px); padding: 2px 8px; font-size: 0.6rem; color: white; text-align: center;">
                        ${booking.category || 'General'}
                    </div>
                </div>
                <div style="display: flex; flex-direction: column; justify-content: space-between;">
                    <div class="booking-event">
                        <h4 style="font-size: 1.1rem; margin-bottom: 0.5rem;">${booking.event_name}</h4>
                        <div class="booking-meta">
                            <span>📍 ${booking.venue}</span>
                            <span>📅 ${dateStr} · ${booking.time}</span>
                            <span style="font-size: 0.75rem; color: var(--text-dim); margin-top: 0.5rem; display: block;">Booked on ${bookDate}</span>
                        </div>
                    </div>
                    <div class="booking-details" style="border-top: 1px solid var(--glass-border); padding-top: 0.8rem; margin-top: 0.8rem;">
                        <div class="detail-item">
                            <div class="detail-value">${booking.tickets_booked}</div>
                            <div class="detail-label">Tickets</div>
                        </div>
                        <div class="detail-item" style="display: flex; flex-direction: column; align-items: flex-end; gap: 0.5rem;">
                            <span class="badge ${statusClass}">${statusText}</span>
                            ${actionHtml}
                        </div>
                    </div>
                </div>
            `;
            container.appendChild(card);
        });
    } catch (error) {
        console.error('Error loading bookings:', error);
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">⚠️</div>
                <h3>Connection Error</h3>
                <p>Unable to load your bookings. Please try again.</p>
                <button class="btn" style="margin-top: 1rem;" onclick="loadMyBookings()">↻ Retry</button>
            </div>`;
    }
}

async function cancelBooking(id) {
    confirmAction({
        title: 'Cancel Booking',
        message: 'Are you sure you want to cancel this booking? This action will release your reserved tickets back to the event pool.',
        icon: '🚫',
        confirmText: 'Yes, Cancel',
        onConfirm: async () => {
            try {
                const response = await fetch(`${API_URL}/bookings/${id}`, {
                    method: 'DELETE',
                    headers: getHeaders()
                });
                
                if (response.ok) {
                    showToast('Booking cancelled successfully.', 'success');
                    loadMyBookings();
                } else {
                    const data = await response.json();
                    showToast(data.message || 'Failed to cancel booking', 'error');
                }
            } catch (error) {
                showToast('Network error', 'error');
            }
        }
    });
}

function viewTicket(id, name, date, time, venue, qty) {
    const modalId = 'ticketModal';
    let modal = document.getElementById(modalId);
    
    if (!modal) {
        modal = document.createElement('div');
        modal.id = modalId;
        modal.className = 'modal';
        document.body.appendChild(modal);
    }

    modal.innerHTML = `
        <div class="ticket-view glass" style="border: none; background: white; color: #1e293b; max-width: 450px; padding: 0; overflow: hidden;">
            <div style="background: var(--primary); padding: 1.5rem; color: white; text-align: center;">
                <h2 style="font-size: 1.5rem; margin-bottom: 0.2rem;">EventHub Ticket</h2>
                <p style="font-size: 0.8rem; opacity: 0.9;">Booking ID: #${id}</p>
            </div>
            <div style="padding: 2rem;">
                <h3 style="font-size: 1.2rem; margin-bottom: 1rem; color: #0f172a;">${name}</h3>
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; font-size: 0.85rem;">
                    <div>
                        <p style="color: #64748b; margin-bottom: 0.2rem;">DATE</p>
                        <p style="font-weight: 700;">${date}</p>
                    </div>
                    <div>
                        <p style="color: #64748b; margin-bottom: 0.2rem;">TIME</p>
                        <p style="font-weight: 700;">${time}</p>
                    </div>
                    <div>
                        <p style="color: #64748b; margin-bottom: 0.2rem;">VENUE</p>
                        <p style="font-weight: 700;">${venue}</p>
                    </div>
                    <div>
                        <p style="color: #64748b; margin-bottom: 0.2rem;">TICKETS</p>
                        <p style="font-weight: 700;">${qty} Person(s)</p>
                    </div>
                </div>
                <div style="margin-top: 2rem; padding-top: 1.5rem; border-top: 2px dashed #e2e8f0; text-align: center;">
                    <div style="background: #f8fafc; padding: 1rem; border-radius: 8px; display: inline-block;">
                        <img src="https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=BOOKING_${id}" alt="QR Code" style="width: 100px; height: 100px;">
                    </div>
                    <p style="font-size: 0.75rem; color: #94a3b8; margin-top: 1rem;">Show this QR code at the venue for check-in</p>
                </div>
            </div>
            <div style="padding: 1rem; background: #f1f5f9; text-align: center;">
                <button class="btn" style="width: 100%;" onclick="this.closest('.modal').classList.remove('active')">Close</button>
            </div>
        </div>
    `;

    modal.classList.add('active');
}

