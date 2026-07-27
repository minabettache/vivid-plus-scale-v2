import Link from 'next/link';
import {
  BarChart3,
  CalendarDays,
  Gift,
  LayoutDashboard,
  Percent,
  ScanLine,
  Settings,
  Users,
} from 'lucide-react';

type OwnerNavigationProps = {
  active?:
    | 'dashboard'
    | 'events'
    | 'promotions'
    | 'rewards'
    | 'members'
    | 'analytics'
    | 'settings';
};

const navigationItems = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    href: '/owner',
    icon: LayoutDashboard,
  },
  {
    id: 'events',
    label: 'Events',
    href: '/owner/events',
    icon: CalendarDays,
  },
  {
    id: 'promotions',
    label: 'Promotions',
    href: '/owner/promotions',
    icon: Percent,
  },
  {
    id: 'rewards',
    label: 'Rewards',
    href: '/owner/rewards',
    icon: Gift,
  },
  {
    id: 'members',
    label: 'Members',
    href: '/owner/members',
    icon: Users,
  },
  {
    id: 'analytics',
    label: 'Analytics',
    href: '/owner/analytics',
    icon: BarChart3,
  },
  {
    id: 'settings',
    label: 'Settings',
    href: '/owner/settings',
    icon: Settings,
  },
] as const;

export function OwnerNavigation({
  active = 'dashboard',
}: OwnerNavigationProps) {
  return (
    <aside
      style={{
        display: 'grid',
        gap: 12,
        alignContent: 'start',
      }}
    >
      <div
        style={{
          padding: 22,
          borderRadius: 22,
          border: '1px solid #303030',
          background:
            'linear-gradient(145deg, #191919 0%, #111111 100%)',
        }}
      >
        <p
          style={{
            margin: 0,
            color: '#f5a623',
            fontSize: 13,
            fontWeight: 900,
            letterSpacing: '0.09em',
          }}
        >
          VIVID+ OWNER
        </p>

        <h2
          style={{
            margin: '10px 0 0',
          }}
        >
          Control Center
        </h2>
      </div>

      <nav
        style={{
          display: 'grid',
          gap: 8,
        }}
      >
        {navigationItems.map(
          ({ id, label, href, icon: Icon }) => {
            const isActive = active === id;

            return (
              <Link
                key={id}
                href={href}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  padding: '14px 16px',
                  borderRadius: 14,
                  border: isActive
                    ? '1px solid #f5a623'
                    : '1px solid #303030',
                  background: isActive
                    ? 'rgba(245, 166, 35, 0.12)'
                    : '#141414',
                  color: isActive ? '#f5a623' : '#ffffff',
                  textDecoration: 'none',
                  fontWeight: 800,
                }}
              >
                <Icon size={19} />

                {label}
              </Link>
            );
          },
        )}
      </nav>

      <Link
        href="/scanner"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          marginTop: 10,
          padding: '14px 16px',
          borderRadius: 14,
          border: '1px solid #303030',
          background: '#141414',
          color: '#ffffff',
          textDecoration: 'none',
          fontWeight: 800,
        }}
      >
        <ScanLine size={19} />

        Open scanner
      </Link>
    </aside>
  );
}