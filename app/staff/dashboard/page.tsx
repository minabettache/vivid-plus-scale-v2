import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/auth/require-staff';

export default async function StaffDashboardPage() {
  let staff;

  try {
    ({ staff } = await requireStaff());
  } catch {
    redirect('/staff/login');
  }

  const canManage =
    staff.role === 'owner' || staff.role === 'admin';

  return (
    <main
      style={{
        minHeight: '100vh',
        padding: 28,
        background: '#090909',
        color: 'white',
      }}
    >
      <section
        style={{
          maxWidth: 900,
          margin: '0 auto',
        }}
      >
        <p
          style={{
            color: '#f5a623',
            fontWeight: 800,
          }}
        >
          VIVID+ STAFF
        </p>

        <h1>Welcome, {staff.full_name}</h1>

        <p>Role: {staff.role}</p>

        <div
          style={{
            marginTop: 28,
            display: 'grid',
            gap: 16,
            gridTemplateColumns:
              'repeat(auto-fit, minmax(220px, 1fr))',
          }}
        >
          <Link
            href="/scanner"
            style={cardStyle}
          >
            <strong>Open secure scanner</strong>

            <br />

            Scan member QR codes and award points.
          </Link>

          {canManage && (
            <Link
              href="/owner"
              style={cardStyle}
            >
              <strong>Owner Dashboard</strong>

              <br />

              Manage events, promotions, rewards and members.
            </Link>
          )}
        </div>
      </section>
    </main>
  );
}

const cardStyle: React.CSSProperties = {
  padding: 22,
  borderRadius: 18,
  border: '1px solid #333',
  color: 'white',
  textDecoration: 'none',
  background: '#151515',
  lineHeight: 1.7,
};