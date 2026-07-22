export type Interest =
  | "Lounge"
  | "Events"
  | "Games"
  | "Food Partner"
  | "Retail & Merch";

export type Member = {
  name: string;
  phone: string;
  email: string;
  birthday: string;
  interests: Interest[];
  memberId: string;
  joinedAt: string;
  membershipLevel: string;
  points: number;

  // Supabase fields
  qr_code?: string;
  is_active?: boolean;
};

export type AppTab =
  | "home"
  | "offers"
  | "rewards"
  | "events"
  | "profile";