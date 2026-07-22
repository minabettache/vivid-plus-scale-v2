'use client';

import {
  CalendarDays,
  Gift,
  MapPin,
  QrCode,
} from 'lucide-react';

type QuickActionsProps = {
  onCard: () => void;
  onEvents: () => void;
};

export function QuickActions({
  onCard,
  onEvents,
}: QuickActionsProps) {
  function openDirections() {
    window.open(
      'https://www.google.com/maps/search/?api=1&query=7216+W+Colonial+Dr+Orlando+FL+32818',
      '_blank',
      'noopener,noreferrer'
    );
  }

  async function shareMembership() {
    const shareData = {
      title: 'Join VIVID+',
      text: 'Join VIVID+ for lounge rewards, events, and member experiences.',
      url: window.location.origin,
    };

    try {
      if (navigator.share) {
        await navigator.share(shareData);
        return;
      }

      await navigator.clipboard.writeText(window.location.origin);
      window.alert('VIVID+ membership link copied!');
    } catch (error) {
      console.error('Unable to share membership:', error);
    }
  }

  return (
    <section className="quick-actions-section">
      <div className="section-head">
        <div>
          <p className="eyebrow small">MEMBER ACCESS</p>
          <h3>Quick actions</h3>
        </div>
      </div>

      <div className="quick-actions-grid">
        <button
          type="button"
          className="quick-action-card"
          onClick={onCard}
        >
          <span className="quick-action-icon">
            <QrCode size={22} />
          </span>

          <span className="quick-action-content">
            <strong>Digital card</strong>
            <small>Open your membership QR</small>
          </span>
        </button>

        <button
          type="button"
          className="quick-action-card"
          onClick={openDirections}
        >
          <span className="quick-action-icon">
            <MapPin size={22} />
          </span>

          <span className="quick-action-content">
            <strong>Directions</strong>
            <small>7216 W Colonial Drive</small>
          </span>
        </button>

        <button
          type="button"
          className="quick-action-card"
          onClick={onEvents}
        >
          <span className="quick-action-icon">
            <CalendarDays size={22} />
          </span>

          <span className="quick-action-content">
            <strong>Events</strong>
            <small>See what is happening</small>
          </span>
        </button>

        <button
          type="button"
          className="quick-action-card"
          onClick={shareMembership}
        >
          <span className="quick-action-icon">
            <Gift size={22} />
          </span>

          <span className="quick-action-content">
            <strong>Refer a friend</strong>
            <small>Share VIVID+ membership</small>
          </span>
        </button>
      </div>
    </section>
  );
}