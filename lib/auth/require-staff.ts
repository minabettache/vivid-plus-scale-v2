import { createClient } from "@/lib/supabase/server";
import type { StaffRole } from "@/lib/permissions";

export type StaffProfile = {
  id: string;
  auth_user_id: string;
  full_name: string;
  role: StaffRole;
  is_active: boolean;
};

export async function requireStaff(): Promise<{
  userId: string;
  staff: StaffProfile;
}> {
  const supabase = await createClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    throw new Error("UNAUTHENTICATED");
  }

  const { data: staff, error: staffError } = await supabase
    .from("staff_users")
    .select("id, auth_user_id, full_name, role, is_active")
    .eq("auth_user_id", user.id)
    .eq("is_active", true)
    .single();

  if (staffError || !staff) {
    throw new Error("STAFF_ACCESS_REQUIRED");
  }

  return { userId: user.id, staff: staff as StaffProfile };
}
