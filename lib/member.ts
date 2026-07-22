import { supabase } from "./supabase";
import type { Member } from "./types";

export function createMemberId(name: string, phone: string) {
  const initials = name
    .replace(/[^a-zA-Z]/g, "")
    .slice(0, 2)
    .toUpperCase()
    .padEnd(2, "X");

  const digits = phone.replace(/\D/g, "").slice(-4).padStart(4, "0");

  return `VVP-${initials}-${digits}`;
}

export async function saveMember(member: Member) {
  return await supabase.from("members").insert([
    {
      full_name: member.name,
      phone: member.phone,
      email: member.email,
      membership_level: member.membershipLevel,
      points: member.points,
      birthday: member.birthday,
      qr_code: member.memberId,
      is_active: true,
    },
  ]);
}

export async function loadMember() {
  const { data } = await supabase
    .from("members")
    .select("*")
    .limit(1)
    .single();

  return data;
}

export async function clearMember() {
  return;
}