'use client';

import {
  BadgePercent,
  CheckCircle2,
  LoaderCircle,
  Sparkles,
} from 'lucide-react';
import {
  useEffect,
  useState,
} from 'react';

type Promotion = {
  id: number;
  title: string;
  description: string | null;
  badge: string;
  terms: string | null;
  start_at: string | null;
  end_at: string | null;
};

function usePromotions() {
  const [promotions, setPromotions] = useState<
    Promotion[]
  >([]);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function loadPromotions() {
      try {
        const response = await fetch(
          '/api/promotions',
          {
            cache: 'no-store',
          },
        );

        const payload = await response.json();

        if (!response.ok) {
          throw new Error(
            payload.error ||
              'Unable to load promotions.',
          );
        }

        setPromotions(payload.promotions ?? []);
      } catch (error) {
        setError(
          error instanceof Error
            ? error.message
            : 'Unable to load promotions.',
        );
      } finally {
        setLoading(false);
      }
    }

    void loadPromotions();
  }, []);

  return {
    promotions,
    loading,
    error,
  };
}

export function FeaturedOffer() {
  const {
    promotions,
    loading,
    error,
  } = usePromotions();

  const [activatedId, setActivatedId] =
    useState<number | null>(null);

  const promotion = promotions[0];

  return (
    <section className="section">
      <div className="section-head">
        <div>
          <p className="eyebrow small">
            TODAY&apos;S EXCLUSIVE
          </p>

          <h3>Featured offer</h3>
        </div>

        <span>Member only</span>
      </div>

      {loading ? (
        <article className="featured-offer">
          <div>
            <p>MEMBER SPECIAL</p>
            <h3>Loading current promotion...</h3>
          </div>

          <LoaderCircle size={56} />
        </article>
      ) : error ? (
        <article className="featured-offer">
          <div>
            <p>VIVID+ OFFERS</p>
            <h3>{error}</h3>
          </div>

          <BadgePercent size={56} />
        </article>
      ) : !promotion ? (
        <article className="featured-offer">
          <div>
            <p>VIVID+ OFFERS</p>

            <h3>
              No member promotions available right
              now.
            </h3>
          </div>

          <BadgePercent size={56} />
        </article>
      ) : (
        <article className="featured-offer">
          <div>
            <p>{promotion.badge}</p>

            <h3>{promotion.title}</h3>

            {promotion.description && (
              <span>
                {promotion.description}
              </span>
            )}

            <button
              type="button"
              onClick={() =>
                setActivatedId(promotion.id)
              }
              disabled={
                activatedId === promotion.id
              }
            >
              {activatedId === promotion.id
                ? 'Offer activated'
                : 'Activate offer'}
            </button>

            {activatedId === promotion.id && (
              <p style={{ marginTop: 12 }}>
                <CheckCircle2 size={16} />{' '}
                {promotion.terms ||
                  'Show this activated offer to staff before payment.'}
              </p>
            )}
          </div>

          <Sparkles size={64} />
        </article>
      )}
    </section>
  );
}

export function OffersPanel() {
  const {
    promotions,
    loading,
    error,
  } = usePromotions();

  const [activatedId, setActivatedId] =
    useState<number | null>(null);

  return (
    <section className="section page-section">
      <div className="section-head">
        <div>
          <p className="eyebrow small">
            VIVID+ MEMBER SPECIALS
          </p>

          <h3>Your offers</h3>
        </div>

        <span>
          {loading
            ? 'Loading'
            : `${promotions.length} available`}
        </span>
      </div>

      {loading ? (
        <article className="offer">
          <div className="icon-box">
            <LoaderCircle />
          </div>

          <div>
            <p>OFFERS</p>
            <h3>Loading member promotions...</h3>
          </div>
        </article>
      ) : error ? (
        <article className="offer">
          <div className="icon-box">
            <BadgePercent />
          </div>

          <div>
            <p>OFFERS</p>
            <h3>{error}</h3>
          </div>
        </article>
      ) : promotions.length === 0 ? (
        <article className="offer">
          <div className="icon-box">
            <BadgePercent />
          </div>

          <div>
            <p>OFFERS</p>

            <h3>
              No member promotions available right
              now.
            </h3>
          </div>
        </article>
      ) : (
        <div className="offer-list">
          {promotions.map((promotion) => (
            <article
              className="offer"
              key={promotion.id}
            >
              <div className="icon-box">
                <BadgePercent />
              </div>

              <div>
                <p>{promotion.badge}</p>

                <h3>{promotion.title}</h3>

                {promotion.description && (
                  <span>
                    {promotion.description}
                  </span>
                )}

                <button
                  type="button"
                  onClick={() =>
                    setActivatedId(
                      promotion.id,
                    )
                  }
                  disabled={
                    activatedId ===
                    promotion.id
                  }
                  style={{ marginTop: 14 }}
                >
                  {activatedId ===
                  promotion.id
                    ? 'Offer activated'
                    : 'Activate offer'}
                </button>

                {activatedId ===
                  promotion.id && (
                  <p style={{ marginTop: 12 }}>
                    <CheckCircle2
                      size={16}
                    />{' '}
                    {promotion.terms ||
                      'Show this activated offer to staff before payment.'}
                  </p>
                )}
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}