import { redirect } from 'next/navigation';
import { OwnerComingSoon } from '@/components/OwnerComingSoon';
import { requireOwner } from '@/lib/auth/require-owner';

export default async function OwnerSettingsPage() {
  try {
    await requireOwner();
  } catch {
    redirect('/staff/login');
  }

  return (
    <OwnerComingSoon
      active="settings"
      title="Settings"
      description="Manage VIVID+ business settings and owner preferences."
    />
  );
}