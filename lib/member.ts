import { createClient } from '@/lib/supabase/client';
import type {
  Interest,
  Member,
  MemberDatabaseRow,
  MembershipLevel
} from '@/lib/types';

export type MemberSignUpInput = {
  fullName: string;
  phone: string;
  email: string;
  password: string;
  birthday: string;
  interests: Interest[];
};

export type MemberSignInInput = {
  email: string;
  password: string;
};

function normalizeMembershipLevel(
  value: string | null
): MembershipLevel {
  switch (value?.toLowerCase()) {
    case 'silver':
      return 'Silver';
    case 'gold':
      return 'Gold';
    case 'platinum':
      return 'Platinum';
    case 'vip':
      return 'VIP';
    default:
      return 'Member';
  }
}

export function mapMemberRow(row: MemberDatabaseRow): Member {
  return {
    databaseId: row.id,
    userId: row.user_id ?? '',
    name: row.full_name ?? 'VIVID+ Member',
    phone: row.phone ?? '',
    email: row.email ?? '',
    birthday: row.birthday ?? '',
    interests: [],
    memberId: row.qr_code ?? `VVP-${row.id}`,
    joinedAt: row.created_at,
    membershipLevel: normalizeMembershipLevel(row.membership_level),
    points: Number(row.points ?? 0),
    lifetimePoints: Number(row.lifetime_points ?? 0),
    totalVisits: Number(row.total_visits ?? 0),
    totalSpent: Number(row.total_spent ?? 0),
    lastVisitAt: row.last_visit_at,
    isActive: row.is_active ?? true
  };
}

export async function getCurrentMember(): Promise<Member | null> {
  const supabase = createClient();

  const {
    data: { user },
    error: userError
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return null;
  }

  const { data, error } = await supabase
    .from('members')
    .select('*')
    .eq('user_id', user.id)
    .maybeSingle<MemberDatabaseRow>();

  if (error) {
    throw new Error(error.message);
  }

  if (!data) {
    return null;
  }

  return mapMemberRow(data);
}

export async function signUpMember(
  input: MemberSignUpInput
): Promise<{
  member: Member | null;
  requiresEmailConfirmation: boolean;
}> {
  const supabase = createClient();

  const { data, error } = await supabase.auth.signUp({
    email: input.email.trim().toLowerCase(),
    password: input.password,
    options: {
      data: {
        full_name: input.fullName.trim(),
        phone: input.phone.trim(),
        birthday: input.birthday,
        interests: input.interests
      }
    }
  });

  if (error) {
    throw new Error(error.message);
  }

  const requiresEmailConfirmation = !data.session;

  if (requiresEmailConfirmation) {
    return {
      member: null,
      requiresEmailConfirmation: true
    };
  }

  const member = await getCurrentMember();

  return {
    member,
    requiresEmailConfirmation: false
  };
}

export async function signInMember(
  input: MemberSignInInput
): Promise<Member> {
  const supabase = createClient();

  const { error } = await supabase.auth.signInWithPassword({
    email: input.email.trim().toLowerCase(),
    password: input.password
  });

  if (error) {
    throw new Error(error.message);
  }

  const member = await getCurrentMember();

  if (!member) {
    throw new Error(
      'Your account was authenticated, but the member profile could not be loaded.'
    );
  }

  return member;
}

export async function signOutMember(): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.auth.signOut();

  if (error) {
    throw new Error(error.message);
  }
}