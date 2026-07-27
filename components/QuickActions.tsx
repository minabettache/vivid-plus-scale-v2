'use client';

import {
  Gift,
  MapPin,
  PartyPopper,
  QrCode,
  WalletCards,
  X,
} from 'lucide-react';
import { useState } from 'react';
import type { Member } from '@/lib/types';

type QuickActionsProps = {
  member: Member;
  onEvents: () => void;
};

export function QuickActions({
  member,
  onEvents,
}: QuickActionsProps) {
  const [showCard, setShowCard] = useState(false);
  const [referralMessage, setReferralMessage] = useState('');

  function openDirections() {
    const address = encodeURIComponent(
      '7216 W Colonial Dr, Orlando, FL 32818'
    );

    window.open(
      `https://www.google.com/maps/search/?api=1&query=${address}`,
      '_blank',
      'noopener,noreferrer'
    );
  }

  async function shareVivid() {
    const message =
      'Join VIVID+ at Vivid Smoke Shop & Lounge, 7216 W Colonial Dr, Orlando, FL 32818.';

    try {
      if (navigator.share) {
        await navigator.share({
          title: 'Join VIVID+',
          text: message,
        });

        setReferralMessage('VIVID+ invitation shared.');
        return;
      }

      await navigator.clipboard.writeText(message);
      setReferralMessage('VIVID+ invitation copied.');
    } catch {
      setReferralMessage('Sharing was cancelled.');
    }
  }

  return (
    <>
      <section className="quick-grid">
        <button
          type="button"
          className="quick-action"
          onClick={() => setShowCard(true)}
        >
          <WalletCards />
          <b>Digital card</b>
          <span>Open your membership card</span>
        </button>

        <button
          type="button"
          className="quick-action"
          onClick={openDirections}
        >
          <MapPin />
          <b>Directions</b>
          <span>7216 W Colonial Dr</span>
        </button>

        <button
          type="button"
          className="quick-action"
          onClick={onEvents}
        >
          <PartyPopper />
          <b>Events</b>
          <span>View upcoming Vivid events</span>
        </button>

        <button
          type="button"
          className="quick-action"
          onClick={shareVivid}
        >
          <Gift />
          <b>Refer a friend</b>
          <span>Share VIVID+ membership</span>
        </button>
      </section>

      {referralMessage && (
        <div className="status-pill">{referralMessage}</div>
      )}

      {showCard && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 100,
            background: 'rgba(0,0,0,0.82)',
            display: 'grid',
            placeItems: 'center',
            padding: 20,
          }}
        >
          <section
            className="membership-card"
            style={{
              width: '100%',
              maxWidth: 430,
              position: 'relative',
            }}
          >
            <button
              type="button"
              aria-label="Close digital card"
              onClick={() => setShowCard(false)}
              style={{
                position: 'absolute',
                right: 16,
                top: 16,
                zIndex: 2,
              }}
            >
              <X size={20} />
            </button>

            <div className="card-top">
              <strong>VIVID+</strong>
              <span>MEMBER CARD</span>
            </div>

            <div className="balance">
              <p>MEMBER</p>
              <strong>{member.name}</strong>
            </div>

            <div className="card-bottom">
              <span>{member.memberId}</span>

              <div className="qr-shell">
                <QrCode size={72} />
              </div>
            </div>

            <p style={{ marginTop: 18 }}>
              Present this membership card to Vivid staff.
            </p>
          </section>
        </div>
      )}
    </>
  );
}