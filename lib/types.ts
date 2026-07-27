export type Interest = 'Lounge' | 'Events';

export type MembershipLevel =
  | 'Member'
  | 'Silver'
  | 'Gold'
  | 'Platinum'
  | 'VIP';

export type MemberDatabaseRow = {
  id: number;
  created_at: string;
  full_name: string | null;
  phone: string | null;
  email: string | null;
  membership_level: string | null;
  points: number | null;
  birthday: string | null;
  qr_code: string | null;
  is_active: boolean | null;
  user_id: string | null;
  lifetime_points: number;
  total_visits: number;
  total_spent: number | string;
  last_visit_at: string | null;
};

export type Member = {
  databaseId: number;
  userId: string;
  name: string;
  phone: string;
  email: string;
  birthday: string;
  interests: Interest[];
  memberId: string;
  joinedAt: string;
  membershipLevel: MembershipLevel;
  points: number;
  lifetimePoints: number;
  totalVisits: number;
  totalSpent: number;
  lastVisitAt: string | null;
  isActive: boolean;
};

export type AppTab =
  | 'home'
  | 'offers'
  | 'rewards'
  | 'events'
  | 'profile';