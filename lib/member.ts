import { supabase } from "./supabase";
import type { Member } from "./types";

export function createMemberId(name: string, phone: string) {
  const initials = name
    .replace(/[^a-zA-Z]/g, "")
    .slice(0, 2)
    .toUpperCase()
    .padEnd(2, "X");

  const digits = phone
    .replace(/\D/g, "")
    .slice(-4)
    .padStart(4, "0");

  return `VVP-${initials}-${digits}`;
}

export async function saveMember(member: Member) {
  const { data, error } = await supabase
    .from("members")
    .insert({
      full_name: member.name,
      phone: member.phone,
      email: member.email,
      membership_level: member.membershipLevel,
      points: member.points,
      birthday: member.birthday,
      qr_code: member.memberId,
      is_active: true,
    })
    .select()
    .single();

  if (error) {
    throw error;
  }

  return data;
}

export async function loadMember(): Promise<Member | null> {
  const { data, error } = await supabase
    .from("members")
    .select("*")
    .limit(1)
    .maybeSingle();

  if (error) {
    throw error;
  }

  if (!data) {
    return null;
  }

  return {
    id: Number(data.id),

    name: data.full_name ?? "VIVID+ Member",
    phone: data.phone ?? "",
    email: data.email ?? "",
    birthday: data.birthday ?? "",
    interests: [],

    memberId: data.qr_code ?? "",
    joinedAt: data.created_at ?? new Date().toISOString(),
    membershipLevel: data.membership_level ?? "Member",
    points: Number(data.points ?? 0),

    qr_code: data.qr_code ?? "",
    is_active: data.is_active ?? true,
  };
}

export async function clearMember() {
  return;
}