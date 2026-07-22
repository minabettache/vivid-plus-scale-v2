'use client';

import { Bell, Sparkles, X } from 'lucide-react';
import { useEffect, useState } from 'react';

import { BottomNavigation } from '@/components/BottomNavigation';
import { EventsPanel } from '@/components/EventsPanel';
import { MembershipCard } from '@/components/MembershipCard';
import { FeaturedOffer, OffersPanel } from '@/components/Offers';
import { Onboarding } from '@/components/Onboarding';
import { ProfilePanel } from '@/components/ProfilePanel';
import { QuickActions } from '@/components/QuickActions';
import { RewardsPanel } from '@/components/RewardsPanel';

import { clearMember, loadMember, saveMember } from '@/lib/member';
import type { AppTab, Member } from '@/lib/types';

export default function HomePage() {
  const [member, setMember] = useState<Member | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<AppTab>('home');
  const [showDigitalCard, setShowDigitalCard] = useState(false);

  useEffect(() => {
    async function getMember() {
      try {
        const savedMember = await loadMember();
        setMember(savedMember);
      } catch (error) {
        console.error('Failed to load member:', error);
        setMember(null);
      } finally {
        setLoading(false);
      }
    }

    void getMember();
  }, []);

  async function join(newMember: Member) {
    try {
      await saveMember(newMember);
      setMember(newMember);
    } catch (error) {
      console.error('Failed to save member:', error);
    }
  }

  async function signOut() {
    try {
      await clearMember();
    } catch (error) {
      console.error('Failed to clear member:', error);
    } finally {
      setShowDigitalCard(false);
      setMember(null);
      setTab('home');
    }
  }

  function openDigitalCard() {
    setShowDigitalCard(true);
  }

  function closeDigitalCard() {
    setShowDigitalCard(false);
  }

  if (loading) {
    return (
      <main className="loading-screen">
        <div className="loading-logo">V+</div>
      </main>
    );
  }

  if (!member) {
    return <Onboarding onJoin={join} />;
  }

  const firstName = member.name?.trim().split(' ')[0] || 'Member';

  const memberSince = member.joinedAt
    ? new Date(member.joinedAt).getFullYear()
    : new Date().getFullYear();

  const points = member.points ?? 640;

  const memberCode =
    member.qr_code?.trim() ||
    member.memberId?.trim() ||
    'VIVID-UNKNOWN-MEMBER';

  /*
   * Important:
   * The QR no longer contains only the telephone number.
   * It contains structured VIVID+ membership text.
   */
  const qrValue = JSON.stringify({
    type: 'VIVID_MEMBER',
    code: memberCode,
  });

  /*
   * version=3 forces the browser and QR service to use
   * a new QR image instead of the older phone-number QR.
   */
  const qrImageUrl =
    'https://api.qrserver.com/v1/create-qr-code/' +
    `?size=300x300&margin=10&format=png&data=${encodeURIComponent(
      qrValue
    )}&version=3`;

  return (
    <main className="app-shell">
      <header className="app-header">
        <div>
          <p className="eyebrow small">WELCOME BACK</p>
          <h1>{firstName}</h1>
        </div>

        <button
          className="notification-button"
          aria-label="Notifications"
          type="button"
        >
          <Bell size={20} />
          <i />
        </button>
      </header>

      {tab === 'home' && (
        <>
          <MembershipCard member={member} points={points} />

          <div className="status-pill">
            <Sparkles size={14} />
            {member.membershipLevel || 'Gold'} status active · Member since{' '}
            {memberSince}
          </div>

          <QuickActions
            onCard={openDigitalCard}
            onEvents={() => setTab('events')}
          />

          <FeaturedOffer />
        </>
      )}

      {tab === 'offers' && <OffersPanel />}

      {tab === 'rewards' && <RewardsPanel points={points} />}

      {tab === 'events' && <EventsPanel />}

      {tab === 'profile' && (
        <ProfilePanel member={member} onSignOut={signOut} />
      )}

      <footer>
        <span>VIVID+</span> Offers are subject to eligibility, age verification,
        and store terms.
      </footer>

      <BottomNavigation active={tab} onChange={setTab} />

      {showDigitalCard && (
        <div
          role="presentation"
          onClick={closeDigitalCard}
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 9999,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '20px',
            background: 'rgba(0, 0, 0, 0.88)',
            backdropFilter: 'blur(10px)',
          }}
        >
          <section
            role="dialog"
            aria-modal="true"
            aria-label="VIVID+ Digital Membership Card"
            onClick={(event) => event.stopPropagation()}
            style={{
              position: 'relative',
              width: '100%',
              maxWidth: '390px',
              padding: '28px',
              border: '1px solid #f5a623',
              borderRadius: '26px',
              background:
                'linear-gradient(145deg, #241508 0%, #111111 55%, #080808 100%)',
              boxShadow: '0 24px 80px rgba(245, 166, 35, 0.25)',
              color: '#ffffff',
              textAlign: 'center',
            }}
          >
            <button
              type="button"
              aria-label="Close digital card"
              onClick={closeDigitalCard}
              style={{
                position: 'absolute',
                top: '14px',
                right: '14px',
                width: '38px',
                height: '38px',
                display: 'grid',
                placeItems: 'center',
                border: '1px solid rgba(255, 255, 255, 0.15)',
                borderRadius: '50%',
                background: 'rgba(255, 255, 255, 0.08)',
                color: '#ffffff',
                cursor: 'pointer',
              }}
            >
              <X size={20} />
            </button>

            <p
              style={{
                margin: 0,
                color: '#f5a623',
                fontSize: '13px',
                fontWeight: 800,
                letterSpacing: '0.12em',
              }}
            >
              VIVID+ DIGITAL CARD
            </p>

            <h2
              style={{
                margin: '10px 0 4px',
                fontSize: '28px',
              }}
            >
              {member.name || 'VIVID+ Member'}
            </h2>

            <p
              style={{
                margin: '0 0 22px',
                color: '#bbbbbb',
              }}
            >
              {member.membershipLevel || 'Gold'} Member · {points} points
            </p>

            <div
              style={{
                width: '260px',
                maxWidth: '100%',
                margin: '0 auto',
                padding: '14px',
                borderRadius: '20px',
                background: '#ffffff',
              }}
            >
              <img
                src={qrImageUrl}
                alt={`VIVID+ QR code for ${member.name || 'member'}`}
                width={232}
                height={232}
                style={{
                  display: 'block',
                  width: '100%',
                  height: 'auto',
                }}
              />
            </div>

            <p
              style={{
                margin: '18px 0 4px',
                color: '#f5a623',
                fontWeight: 800,
                wordBreak: 'break-word',
              }}
            >
              Member code: {memberCode}
            </p>

            <p
              style={{
                margin: 0,
                color: '#999999',
                fontSize: '13px',
                lineHeight: 1.5,
              }}
            >
              Present this QR code to VIVID+ staff.
            </p>
          </section>
        </div>
      )}
    </main>
  );
}