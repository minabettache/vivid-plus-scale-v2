import { requireStaff } from '@/lib/auth/require-staff';

export async function requireOwner() {
  const result = await requireStaff();

  if (!['admin', 'owner'].includes(result.staff.role)) {
    throw new Error('OWNER_ACCESS_REQUIRED');
  }

  return result;
}