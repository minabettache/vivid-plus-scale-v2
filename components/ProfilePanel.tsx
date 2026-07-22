import { Bell, LogOut, Settings, ShieldCheck, UserRound } from 'lucide-react';
import type { Member } from '@/lib/types';

export function ProfilePanel({ member, onSignOut }: { member: Member; onSignOut: () => void }) {
  return <section className="section page-section"><div className="profile-hero"><div className="avatar large">{member.name.charAt(0).toUpperCase()}</div><div><p className="eyebrow small">GOLD MEMBER</p><h3>{member.name}</h3><span>{member.memberId}</span></div></div><div className="settings-list"><button><UserRound /> Personal information <span>›</span></button><button><Bell /> Notification preferences <span>›</span></button><button><ShieldCheck /> Privacy & membership terms <span>›</span></button><button><Settings /> App settings <span>›</span></button></div><button className="danger-button" onClick={onSignOut}><LogOut size={17} /> Sign out of this device</button></section>;
}
