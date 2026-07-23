export type Interest =
  | "Lounge"
  | "Events"
  | "Games"
  | "Food Partner"
  | "Retail & Merch";

export type Member = {
  id?: number;

  name: string;
  phone: string;
  email: string;
  birthday: string;
  interests: Interest[];

  memberId: string;
  joinedAt: string;
  membershipLevel: string;
  points: number;

  qr_code?: string;
  is_active?: boolean;
};

export type AppTab =
  | "home"
  | "offers"
  | "rewards"
  | "events"
  | "profile";