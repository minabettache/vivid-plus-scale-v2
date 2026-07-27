import { redirect } from 'next/navigation';
import { OwnerNavigation } from '@/components/OwnerNavigation';
import { OwnerPromotionsManager } from '@/components/OwnerPromotionsManager';
import { requireOwner } from '@/lib/auth/require-owner';

export default async function OwnerPromotionsPage() {
  let owner;

  try {
    const result = await requireOwner();
    owner = result.staff;
  } catch {
    redirect('/staff/login');
  }

  return (
    <main
      style={{
        minHeight: '100vh',
        padding: 24,
        background: '#090909',
        color: '#ffffff',
      }}
    >
      <section
        style={{
          maxWidth: 1250,
          margin: '0 auto',
          display: 'grid',
          gridTemplateColumns:
            'minmax(220px, 260px) minmax(0, 1fr)',
          gap: 28,
        }}
      >
        <OwnerNavigation active="promotions" />

        <div>
          <p
            style={{
              margin: 0,
              color: '#f5a623',
              fontSize: 13,
              fontWeight: 900,
              letterSpacing: '0.09em',
            }}
          >
            VIVID+ OWNER
          </p>

          <h1
            style={{
              margin: '14px 0 0',
              fontSize:
                'clamp(2.5rem, 7vw, 5rem)',
              lineHeight: 1,
            }}
          >
            Promotion Manager
          </h1>

          <p
            style={{
              color: '#aaaaaa',
              marginTop: 18,
              marginBottom: 30,
            }}
          >
            Signed in as {owner.full_name}
          </p>

          <OwnerPromotionsManager />
        </div>
      </section>
    </main>
  );
}