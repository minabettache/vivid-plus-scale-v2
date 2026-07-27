'use client';

import { Bell, Loader2, Sparkles } from 'lucide-react';
import { useEffect, useState } from 'react';
import { BottomNavigation } from '@/components/BottomNavigation';
import { EventsPanel } from '@/components/EventsPanel';
import { MembershipCard } from '@/components/MembershipCard';
import { FeaturedOffer, OffersPanel } from '@/components/Offers';
import { Onboarding } from '@/components/Onboarding';
import { ProfilePanel } from '@/components/ProfilePanel';
import { QuickActions } from '@/components/QuickActions';
import { RewardsPanel } from '@/components/RewardsPanel';
import {
  getCurrentMember,
  signOutMember
} from '@/lib/member';
import type { AppTab, Member } from '@/lib/types';

export default function HomePage() {
  const [member, setMember] = useState<Member | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [tab, setTab] = useState<AppTab>('home');

  useEffect(() => {
    let active = true;

    async function loadMember() {
      try {
        const currentMember = await getCurrentMember();

        if (active) {
          setMember(currentMember);
        }
      } catch (caughtError) {
        if (active) {
          setError(
            caughtError instanceof Error
              ? caughtError.message
              : 'Unable to load your VIVID+ membership.'
          );
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    void loadMember();

    return () => {
      active = false;
    };
  }, []);

  function handleAuthenticated(authenticatedMember: Member) {
    setMember(authenticatedMember);
    setError('');
    setTab('home');
  }

  async function handleSignOut() {
    try {
      await signOutMember();
      setMember(null);
      setTab('home');
      setError('');
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : 'Unable to sign out.'
      );
    }
  }

  if (loading) {
    return (
      <main className="loading-screen">
        <div className="loading-logo">V+</div>

        <div className="loading-status">
          <Loader2 className="spin" size={20} />
          Loading membership...
        </div>
      </main>
    );
  }

  if (!member) {
    return (
      <>
        {error && (
          <div className="global-auth-error">
            {error}
          </div>
        )}

        <Onboarding onAuthenticated={handleAuthenticated} />
      </>
    );
  }

  return (
    <main className="app-shell">
      <header className="app-header">
        <div>
          <p className="eyebrow small">WELCOME BACK</p>
          <h1>
            {member.name.trim().split(/\s+/)[0] || 'Member'}
          </h1>
        </div>

        <button
          type="button"
          className="notification-button"
          aria-label="Notifications"
        >
          <Bell size={20} />
          <i />
        </button>
      </header>

      {error && (
        <div className="auth-message error">
          {error}
        </div>
      )}

      {tab === 'home' && (
        <>
          <MembershipCard
            member={member}
            points={member.points}
          />

          <div className="status-pill">
            <Sparkles size={14} />
            {member.membershipLevel} status active · Member since{' '}
            {new Date(member.joinedAt).getFullYear()}
          </div>

          <QuickActions
            member={member}
            onEvents={() => setTab('events')}
          />

          <FeaturedOffer />
        </>
      )}

      {tab === 'offers' && <OffersPanel />}

      {tab === 'rewards' && (
        <RewardsPanel points={member.points} />
      )}

      {tab === 'events' && <EventsPanel />}

      {tab === 'profile' && (
        <ProfilePanel
          member={member}
          onSignOut={() => {
            void handleSignOut();
          }}
        />
      )}

      <footer>
        <span>VIVID+</span> Offers are subject to eligibility,
        age verification, and store terms.
      </footer>

      <BottomNavigation
        active={tab}
        onChange={setTab}
      />
    </main>
  );
}