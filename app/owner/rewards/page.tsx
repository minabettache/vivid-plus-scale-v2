import { redirect } from 'next/navigation';
import { OwnerComingSoon } from '@/components/OwnerComingSoon';
import { requireOwner } from '@/lib/auth/require-owner';

export default async function OwnerRewardsPage() {
  try {
    await requireOwner();
  } catch {
    redirect('/staff/login');
  }

  return (
    <OwnerComingSoon
      active="rewards"
      title="Reward Manager"
      description="Manage Free Drink, Free Hookah and Drink + Hookah rewards."
    />
  );
}