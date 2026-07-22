import { CalendarDays, Gift, Home, Percent, UserRound } from 'lucide-react';
import type { AppTab } from '@/lib/types';

const items = [
  { id: 'home' as const, label: 'Home', icon: Home },
  { id: 'offers' as const, label: 'Offers', icon: Percent },
  { id: 'rewards' as const, label: 'Rewards', icon: Gift },
  { id: 'events' as const, label: 'Events', icon: CalendarDays },
  { id: 'profile' as const, label: 'Profile', icon: UserRound }
];

export function BottomNavigation({ active, onChange }: { active: AppTab; onChange: (tab: AppTab) => void }) {
  return <nav className="bottom-nav">{items.map(({ id, label, icon: Icon }) => <button key={id} className={active === id ? 'active' : ''} onClick={() => onChange(id)}><Icon size={19} /><span>{label}</span></button>)}</nav>;
}
