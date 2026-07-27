export const STAFF_ROLES = ["staff", "manager", "admin", "owner"] as const;
export type StaffRole = (typeof STAFF_ROLES)[number];

const roleRank: Record<StaffRole, number> = {
  staff: 1,
  manager: 2,
  admin: 3,
  owner: 4,
};

export function hasMinimumRole(current: StaffRole, minimum: StaffRole) {
  return roleRank[current] >= roleRank[minimum];
}

export function isStaffRole(value: unknown): value is StaffRole {
  return typeof value === "string" && STAFF_ROLES.includes(value as StaffRole);
}
