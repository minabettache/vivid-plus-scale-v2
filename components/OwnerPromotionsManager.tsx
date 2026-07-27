'use client';

import {
  BadgePercent,
  Pencil,
  Plus,
  Save,
  Trash2,
  X,
} from 'lucide-react';
import {
  FormEvent,
  useEffect,
  useState,
} from 'react';

type PromotionRecord = {
  id: number;
  title: string;
  description: string | null;
  badge: string;
  terms: string | null;
  start_at: string | null;
  end_at: string | null;
  is_published: boolean;
};

type PromotionForm = {
  title: string;
  description: string;
  badge: string;
  terms: string;
  startAt: string;
  endAt: string;
  isPublished: boolean;
};

const emptyForm: PromotionForm = {
  title: '',
  description: '',
  badge: 'MEMBER SPECIAL',
  terms: '',
  startAt: '',
  endAt: '',
  isPublished: false,
};

function toLocalInput(value: string | null) {
  if (!value) {
    return '';
  }

  const date = new Date(value);
  const offset = date.getTimezoneOffset();

  return new Date(
    date.getTime() - offset * 60_000,
  )
    .toISOString()
    .slice(0, 16);
}

function formatDate(value: string | null) {
  if (!value) {
    return 'No limit';
  }

  return new Intl.DateTimeFormat('en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

export function OwnerPromotionsManager() {
  const [promotions, setPromotions] = useState<
    PromotionRecord[]
  >([]);

  const [form, setForm] =
    useState<PromotionForm>(emptyForm);

  const [editingId, setEditingId] = useState<
    number | null
  >(null);

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    void loadPromotions();
  }, []);

  async function loadPromotions() {
    setLoading(true);

    try {
      const response = await fetch(
        '/api/owner/promotions',
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
      setMessage(
        error instanceof Error
          ? error.message
          : 'Unable to load promotions.',
      );
    } finally {
      setLoading(false);
    }
  }

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
  }

  function editPromotion(
    promotion: PromotionRecord,
  ) {
    setEditingId(promotion.id);

    setForm({
      title: promotion.title,
      description:
        promotion.description ?? '',
      badge: promotion.badge,
      terms: promotion.terms ?? '',
      startAt: toLocalInput(
        promotion.start_at,
      ),
      endAt: toLocalInput(promotion.end_at),
      isPublished:
        promotion.is_published,
    });

    window.scrollTo({
      top: 0,
      behavior: 'smooth',
    });
  }

  async function submitPromotion(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    if (saving) {
      return;
    }

    setSaving(true);
    setMessage('');

    try {
      const response = await fetch(
        editingId
          ? `/api/owner/promotions/${editingId}`
          : '/api/owner/promotions',
        {
          method: editingId
            ? 'PATCH'
            : 'POST',
          headers: {
            'Content-Type':
              'application/json',
          },
          body: JSON.stringify(form),
        },
      );

      const payload = await response.json();

      if (!response.ok) {
        throw new Error(
          payload.error ||
            'Unable to save the promotion.',
        );
      }

      setMessage(
        editingId
          ? 'Promotion updated successfully.'
          : 'Promotion created successfully.',
      );

      resetForm();
      await loadPromotions();
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : 'Unable to save the promotion.',
      );
    } finally {
      setSaving(false);
    }
  }

  async function deletePromotion(
    promotion: PromotionRecord,
  ) {
    const confirmed = window.confirm(
      `Delete "${promotion.title}"?`,
    );

    if (!confirmed) {
      return;
    }

    try {
      const response = await fetch(
        `/api/owner/promotions/${promotion.id}`,
        {
          method: 'DELETE',
        },
      );

      const payload = await response.json();

      if (!response.ok) {
        throw new Error(
          payload.error ||
            'Unable to delete the promotion.',
        );
      }

      setMessage('Promotion deleted.');
      await loadPromotions();
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : 'Unable to delete the promotion.',
      );
    }
  }

  return (
    <div
      style={{
        display: 'grid',
        gap: 28,
      }}
    >
      <form
        onSubmit={submitPromotion}
        style={panelStyle}
      >
        <div style={headingRowStyle}>
          <div>
            <p style={eyebrowStyle}>
              {editingId
                ? 'EDIT PROMOTION'
                : 'NEW PROMOTION'}
            </p>

            <h2>
              {editingId
                ? 'Update promotion'
                : 'Publish a member promotion'}
            </h2>
          </div>

          {editingId && (
            <button
              type="button"
              onClick={resetForm}
              style={iconButtonStyle}
              aria-label="Cancel editing"
            >
              <X size={20} />
            </button>
          )}
        </div>

        <div style={formGridStyle}>
          <label style={labelStyle}>
            Promotion title
            <input
              required
              value={form.title}
              onChange={(event) =>
                setForm({
                  ...form,
                  title: event.target.value,
                })
              }
              placeholder="Get 10% off your bill"
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Badge
            <input
              value={form.badge}
              onChange={(event) =>
                setForm({
                  ...form,
                  badge: event.target.value,
                })
              }
              placeholder="MEMBER SPECIAL"
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Starts
            <input
              type="datetime-local"
              value={form.startAt}
              onChange={(event) =>
                setForm({
                  ...form,
                  startAt:
                    event.target.value,
                })
              }
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Ends
            <input
              type="datetime-local"
              value={form.endAt}
              onChange={(event) =>
                setForm({
                  ...form,
                  endAt:
                    event.target.value,
                })
              }
              style={inputStyle}
            />
          </label>
        </div>

        <label
          style={{
            ...labelStyle,
            marginTop: 18,
          }}
        >
          Description
          <textarea
            value={form.description}
            onChange={(event) =>
              setForm({
                ...form,
                description:
                  event.target.value,
              })
            }
            rows={4}
            placeholder="Describe the promotion."
            style={textareaStyle}
          />
        </label>

        <label
          style={{
            ...labelStyle,
            marginTop: 18,
          }}
        >
          Terms
          <textarea
            value={form.terms}
            onChange={(event) =>
              setForm({
                ...form,
                terms: event.target.value,
              })
            }
            rows={3}
            placeholder="Show to staff before payment."
            style={textareaStyle}
          />
        </label>

        <label style={checkboxStyle}>
          <input
            type="checkbox"
            checked={form.isPublished}
            onChange={(event) =>
              setForm({
                ...form,
                isPublished:
                  event.target.checked,
              })
            }
          />

          Publish immediately to the customer app
        </label>

        <button
          type="submit"
          disabled={saving}
          style={primaryButtonStyle}
        >
          {editingId ? (
            <Save size={18} />
          ) : (
            <Plus size={18} />
          )}

          {saving
            ? 'Saving...'
            : editingId
              ? 'Save changes'
              : 'Create promotion'}
        </button>
      </form>

      {message && (
        <div role="status" style={messageStyle}>
          {message}
        </div>
      )}

      <section>
        <p style={eyebrowStyle}>
          PROMOTION LIBRARY
        </p>

        <h2>Published and draft promotions</h2>

        {loading ? (
          <p>Loading promotions...</p>
        ) : promotions.length === 0 ? (
          <div style={emptyStyle}>
            <BadgePercent size={34} />

            <h3>No promotions created yet</h3>

            <p>
              Create your first promotion using
              the form above.
            </p>
          </div>
        ) : (
          <div
            style={{
              display: 'grid',
              gap: 16,
            }}
          >
            {promotions.map((promotion) => (
              <article
                key={promotion.id}
                style={promotionCardStyle}
              >
                <div style={promotionIconStyle}>
                  <BadgePercent size={23} />
                </div>

                <div style={{ flex: 1 }}>
                  <span
                    style={{
                      color:
                        promotion.is_published
                          ? '#74d88b'
                          : '#f5a623',
                      fontWeight: 900,
                      fontSize: 13,
                    }}
                  >
                    {promotion.is_published
                      ? 'PUBLISHED'
                      : 'DRAFT'}
                  </span>

                  <h3>{promotion.title}</h3>

                  <p style={{ color: '#aaa' }}>
                    {formatDate(
                      promotion.start_at,
                    )}
                    {' → '}
                    {formatDate(
                      promotion.end_at,
                    )}
                  </p>

                  {promotion.terms && (
                    <p>{promotion.terms}</p>
                  )}
                </div>

                <div
                  style={{
                    display: 'flex',
                    gap: 10,
                  }}
                >
                  <button
                    type="button"
                    onClick={() =>
                      editPromotion(promotion)
                    }
                    style={iconButtonStyle}
                    aria-label="Edit promotion"
                  >
                    <Pencil size={18} />
                  </button>

                  <button
                    type="button"
                    onClick={() =>
                      deletePromotion(promotion)
                    }
                    style={{
                      ...iconButtonStyle,
                      color: '#ff7b7b',
                    }}
                    aria-label="Delete promotion"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

const panelStyle: React.CSSProperties = {
  padding: 24,
  border: '1px solid #333',
  borderRadius: 22,
  background: '#151515',
};

const headingRowStyle: React.CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  gap: 20,
};

const eyebrowStyle: React.CSSProperties = {
  margin: 0,
  color: '#f5a623',
  fontWeight: 900,
  letterSpacing: '0.06em',
};

const formGridStyle: React.CSSProperties = {
  display: 'grid',
  gap: 16,
  gridTemplateColumns:
    'repeat(auto-fit, minmax(220px, 1fr))',
  marginTop: 24,
};

const labelStyle: React.CSSProperties = {
  display: 'grid',
  gap: 8,
  fontWeight: 800,
};

const inputStyle: React.CSSProperties = {
  width: '100%',
  boxSizing: 'border-box',
  padding: 14,
  borderRadius: 12,
  border: '1px solid #555',
  background: '#0d0d0d',
  color: '#fff',
  fontSize: 16,
};

const textareaStyle: React.CSSProperties = {
  ...inputStyle,
  resize: 'vertical',
};

const checkboxStyle: React.CSSProperties = {
  display: 'flex',
  gap: 10,
  alignItems: 'center',
  marginTop: 18,
};

const primaryButtonStyle: React.CSSProperties = {
  width: '100%',
  marginTop: 22,
  padding: 16,
  border: 0,
  borderRadius: 14,
  background: '#f5a623',
  color: '#111',
  fontWeight: 900,
  fontSize: 16,
  cursor: 'pointer',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  gap: 8,
};

const iconButtonStyle: React.CSSProperties = {
  display: 'grid',
  placeItems: 'center',
  width: 42,
  height: 42,
  borderRadius: 12,
  border: '1px solid #444',
  background: '#222',
  color: '#fff',
  cursor: 'pointer',
};

const messageStyle: React.CSSProperties = {
  padding: 14,
  borderRadius: 14,
  border: '1px solid #444',
  background: '#191919',
};

const emptyStyle: React.CSSProperties = {
  padding: 30,
  border: '1px dashed #555',
  borderRadius: 20,
  textAlign: 'center',
  color: '#bbb',
};

const promotionCardStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 18,
  padding: 18,
  border: '1px solid #333',
  borderRadius: 18,
  background: '#151515',
};

const promotionIconStyle: React.CSSProperties = {
  display: 'grid',
  placeItems: 'center',
  width: 54,
  height: 54,
  borderRadius: 16,
  background: 'rgba(245,166,35,0.14)',
  color: '#f5a623',
};