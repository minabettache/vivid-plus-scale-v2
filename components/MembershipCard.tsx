import { Crown, QrCode } from 'lucide-react';
import type { Member } from '@/lib/types';

export function MembershipCard({ member, points }: { member: Member; points: number }) {
  const progress = Math.min(100, Math.round((points / 1000) * 100));
  return (
    <section className="membership-card">
      <div className="card-shine" />
      <div className="card-top"><strong>VIVID+</strong><span className="tier"><Crown size={12} /> GOLD</span></div>
      <div className="balance"><p>AVAILABLE BALANCE</p><strong>{points.toLocaleString()} <small>POINTS</small></strong></div>
      <div><div className="progress"><i style={{ width: `${progress}%` }} /></div><p className="progress-copy">{Math.max(0, 1000 - points)} points until Platinum</p></div>
      <div className="card-bottom"><span>{member.memberId}</span><div className="qr-shell"><QrCode size={38} /></div></div>
    </section>
  );
}
