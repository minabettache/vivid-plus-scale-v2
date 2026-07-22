import {
  Bell,
  LogOut,
  Settings,
  ShieldCheck,
  UserRound,
} from 'lucide-react';

import type { Member } from '@/lib/types';

type ProfilePanelProps = {
  member: Member;
  onSignOut: () => void;
};

export function ProfilePanel({
  member,
  onSignOut,
}: ProfilePanelProps) {
  const memberName = member.name?.trim() || 'VIVID+ Member';

  const initial =
    memberName.charAt(0).toUpperCase() || 'V';

  const membershipLevel =
    member.membershipLevel?.trim() || 'Gold';

  const memberCode =
    member.memberId?.trim() ||
    member.qr_code?.trim() ||
    'Member account';

  return (
    <section className="section page-section">
      <div className="profile-hero">
        <div className="avatar large">
          {initial}
        </div>

        <div>
          <p className="eyebrow small">
            {membershipLevel.toUpperCase()} MEMBER
          </p>

          <h3>{memberName}</h3>

          <span>{memberCode}</span>
        </div>
      </div>

      <div className="settings-list">
        <button type="button">
          <UserRound size={19} />
          <span>Personal information</span>
          <strong>›</strong>
        </button>

        <button type="button">
          <Bell size={19} />
          <span>Notification preferences</span>
          <strong>›</strong>
        </button>

        <button type="button">
          <ShieldCheck size={19} />
          <span>Privacy & membership terms</span>
          <strong>›</strong>
        </button>

        <button type="button">
          <Settings size={19} />
          <span>App settings</span>
          <strong>›</strong>
        </button>
      </div>

      <button
        type="button"
        className="danger-button"
        onClick={onSignOut}
      >
        <LogOut size={17} />
        Sign out of this device
      </button>
    </section>
  );
}