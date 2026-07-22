'use client';

import {
  CalendarDays,
  CreditCard,
  Gift,
  Home,
  UserRound
} from 'lucide-react';

export type CustomerTab =
  | 'home'
  | 'events'
  | 'rewards'
  | 'card'
  | 'profile';

type BottomNavigationProps = {
  activeTab: CustomerTab;
  onTabChange: (tab: CustomerTab) => void;
};

const navigationItems = [
  {
    id: 'home',
    label: 'Home',
    icon: Home
  },
  {
    id: 'events',
    label: 'Events',
    icon: CalendarDays
  },
  {
    id: 'rewards',
    label: 'Rewards',
    icon: Gift
  },
  {
    id: 'card',
    label: 'Card',
    icon: CreditCard
  },
  {
    id: 'profile',
    label: 'Profile',
    icon: UserRound
  }
] satisfies Array<{
  id: CustomerTab;
  label: string;
  icon: typeof Home;
}>;

export function BottomNavigation({
  activeTab,
  onTabChange
}: BottomNavigationProps) {
  return (
    <nav
      className="bottom-navigation"
      aria-label="Customer navigation"
    >
      {navigationItems.map((item) => {
        const Icon = item.icon;
        const selected = activeTab === item.id;

        return (
          <button
            key={item.id}
            type="button"
            className={`bottom-navigation-item ${
              selected ? 'active' : ''
            }`}
            onClick={() => onTabChange(item.id)}
            aria-current={selected ? 'page' : undefined}
          >
            <span className="bottom-navigation-icon">
              <Icon size={21} strokeWidth={selected ? 2.5 : 2} />
            </span>

            <span>{item.label}</span>
          </button>
        );
      })}
    </nav>
  );
}