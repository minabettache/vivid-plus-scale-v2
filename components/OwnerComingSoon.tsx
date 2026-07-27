import { OwnerNavigation } from '@/components/OwnerNavigation';

type OwnerSection =
  | 'promotions'
  | 'rewards'
  | 'members'
  | 'analytics'
  | 'settings';

type OwnerComingSoonProps = {
  active: OwnerSection;
  title: string;
  description: string;
};

export function OwnerComingSoon({
  active,
  title,
  description,
}: OwnerComingSoonProps) {
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
        <OwnerNavigation active={active} />

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
              fontSize: 'clamp(2.5rem, 7vw, 5rem)',
              lineHeight: 1,
            }}
          >
            {title}
          </h1>

          <p
            style={{
              color: '#aaaaaa',
              marginTop: 18,
              fontSize: 17,
            }}
          >
            {description}
          </p>

          <section
            style={{
              marginTop: 34,
              padding: 32,
              borderRadius: 22,
              border: '1px dashed #444444',
              background: '#141414',
            }}
          >
            <p
              style={{
                margin: 0,
                color: '#f5a623',
                fontWeight: 900,
              }}
            >
              COMING NEXT
            </p>

            <h2
              style={{
                marginTop: 12,
              }}
            >
              This section is ready to be built.
            </h2>

            <p
              style={{
                color: '#9d9d9d',
                lineHeight: 1.7,
                maxWidth: 650,
              }}
            >
              The page now exists, so the navigation will no longer show a
              404 error. We can connect the real database tools next.
            </p>
          </section>
        </div>
      </section>
    </main>
  );
}