'use client';

import {
  CalendarDays,
  ImagePlus,
  LoaderCircle,
  Pencil,
  Plus,
  Save,
  Trash2,
  Upload,
  X,
} from 'lucide-react';
import { FormEvent, useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

type EventRecord = {
  id: string;
  title: string;
  description: string | null;
  event_date: string;
  start_time: string | null;
  end_time: string | null;
  flyer_url: string | null;
  flyer_path: string | null;
  tag: string;
  dj: string | null;
  admission: string | null;
  is_published: boolean;
};

type EventForm = {
  title: string;
  description: string;
  eventDate: string;
  startTime: string;
  endTime: string;
  flyerUrl: string;
  flyerPath: string;
  tag: string;
  dj: string;
  admission: string;
  isPublished: boolean;
};

const emptyForm: EventForm = {
  title: '',
  description: '',
  eventDate: '',
  startTime: '',
  endTime: '',
  flyerUrl: '',
  flyerPath: '',
  tag: 'VIVID EVENT',
  dj: '',
  admission: '',
  isPublished: false,
};

export function OwnerEventsManager() {
  const [events, setEvents] = useState<EventRecord[]>([]);
  const [form, setForm] = useState<EventForm>(emptyForm);
  const [editingId, setEditingId] = useState<string | null>(
    null,
  );
  const [flyer, setFlyer] = useState<File | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    void loadEvents();
  }, []);

  async function loadEvents() {
    setLoading(true);

    try {
      const response = await fetch('/api/owner/events', {
        cache: 'no-store',
      });

      const payload = await response.json();

      if (!response.ok) {
        throw new Error(
          payload.error || 'Unable to load events.',
        );
      }

      setEvents(payload.events ?? []);
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : 'Unable to load events.',
      );
    } finally {
      setLoading(false);
    }
  }

  function resetForm() {
    setForm(emptyForm);
    setEditingId(null);
    setFlyer(null);
  }

  function editEvent(event: EventRecord) {
    setEditingId(event.id);

    setForm({
      title: event.title,
      description: event.description ?? '',
      eventDate: event.event_date,
      startTime: event.start_time?.slice(0, 5) ?? '',
      endTime: event.end_time?.slice(0, 5) ?? '',
      flyerUrl: event.flyer_url ?? '',
      flyerPath: event.flyer_path ?? '',
      tag: event.tag,
      dj: event.dj ?? '',
      admission: event.admission ?? '',
      isPublished: event.is_published,
    });

    setFlyer(null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  async function uploadFlyer() {
    if (!flyer) {
      return {
        flyerUrl: form.flyerUrl,
        flyerPath: form.flyerPath,
      };
    }

    const supabase = createClient();

    const extension =
      flyer.name.split('.').pop()?.toLowerCase() || 'jpg';

    const safeName = `${crypto.randomUUID()}.${extension}`;

    const path = `events/${safeName}`;

    const { error } = await supabase.storage
      .from('event-flyers')
      .upload(path, flyer, {
        cacheControl: '3600',
        upsert: false,
        contentType: flyer.type,
      });

    if (error) {
      throw new Error(error.message);
    }

    const { data } = supabase.storage
      .from('event-flyers')
      .getPublicUrl(path);

    return {
      flyerUrl: data.publicUrl,
      flyerPath: path,
    };
  }

  async function submitEvent(
    event: FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault();

    if (saving) {
      return;
    }

    setSaving(true);
    setMessage('');

    try {
      const uploadedFlyer = await uploadFlyer();

      const response = await fetch(
        editingId
          ? `/api/owner/events/${editingId}`
          : '/api/owner/events',
        {
          method: editingId ? 'PATCH' : 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            ...form,
            ...uploadedFlyer,
          }),
        },
      );

      const payload = await response.json();

      if (!response.ok) {
        throw new Error(
          payload.error || 'Unable to save the event.',
        );
      }

      setMessage(
        editingId
          ? 'Event updated successfully.'
          : 'Event created successfully.',
      );

      resetForm();
      await loadEvents();
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : 'Unable to save the event.',
      );
    } finally {
      setSaving(false);
    }
  }

  async function deleteEvent(event: EventRecord) {
    const confirmed = window.confirm(
      `Delete "${event.title}"?`,
    );

    if (!confirmed) {
      return;
    }

    try {
      const response = await fetch(
        `/api/owner/events/${event.id}`,
        {
          method: 'DELETE',
        },
      );

      const payload = await response.json();

      if (!response.ok) {
        throw new Error(
          payload.error || 'Unable to delete the event.',
        );
      }

      setMessage('Event deleted.');
      await loadEvents();
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : 'Unable to delete the event.',
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
        onSubmit={submitEvent}
        style={{
          padding: 24,
          border: '1px solid #333',
          borderRadius: 22,
          background: '#151515',
        }}
      >
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            gap: 20,
            alignItems: 'center',
          }}
        >
          <div>
            <p
              style={{
                margin: 0,
                color: '#f5a623',
                fontWeight: 900,
              }}
            >
              {editingId ? 'EDIT EVENT' : 'NEW EVENT'}
            </p>

            <h2 style={{ marginBottom: 0 }}>
              {editingId
                ? 'Update event'
                : 'Publish a Vivid event'}
            </h2>
          </div>

          {editingId && (
            <button
              type="button"
              onClick={resetForm}
              style={iconButtonStyle}
            >
              <X size={20} />
            </button>
          )}
        </div>

        <div style={formGridStyle}>
          <label style={labelStyle}>
            Event name
            <input
              required
              value={form.title}
              onChange={(event) =>
                setForm({
                  ...form,
                  title: event.target.value,
                })
              }
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Event date
            <input
              required
              type="date"
              value={form.eventDate}
              onChange={(event) =>
                setForm({
                  ...form,
                  eventDate: event.target.value,
                })
              }
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Start time
            <input
              type="time"
              value={form.startTime}
              onChange={(event) =>
                setForm({
                  ...form,
                  startTime: event.target.value,
                })
              }
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            End time
            <input
              type="time"
              value={form.endTime}
              onChange={(event) =>
                setForm({
                  ...form,
                  endTime: event.target.value,
                })
              }
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Event tag
            <input
              value={form.tag}
              onChange={(event) =>
                setForm({
                  ...form,
                  tag: event.target.value,
                })
              }
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            DJ or host
            <input
              value={form.dj}
              onChange={(event) =>
                setForm({
                  ...form,
                  dj: event.target.value,
                })
              }
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Admission
            <input
              value={form.admission}
              onChange={(event) =>
                setForm({
                  ...form,
                  admission: event.target.value,
                })
              }
              placeholder="Free before 12 AM"
              style={inputStyle}
            />
          </label>

          <label style={labelStyle}>
            Flyer
            <span
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                padding: 14,
                border: '1px dashed #666',
                borderRadius: 12,
                cursor: 'pointer',
              }}
            >
              <ImagePlus size={19} />

              {flyer
                ? flyer.name
                : form.flyerUrl
                  ? 'Replace current flyer'
                  : 'Choose flyer image'}

              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                onChange={(event) =>
                  setFlyer(event.target.files?.[0] ?? null)
                }
                style={{ display: 'none' }}
              />
            </span>
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
                description: event.target.value,
              })
            }
            rows={5}
            style={{
              ...inputStyle,
              resize: 'vertical',
            }}
          />
        </label>

        <label
          style={{
            display: 'flex',
            gap: 10,
            alignItems: 'center',
            marginTop: 18,
          }}
        >
          <input
            type="checkbox"
            checked={form.isPublished}
            onChange={(event) =>
              setForm({
                ...form,
                isPublished: event.target.checked,
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
          {saving ? (
            <LoaderCircle size={18} />
          ) : editingId ? (
            <Save size={18} />
          ) : (
            <Upload size={18} />
          )}

          {saving
            ? 'Saving...'
            : editingId
              ? 'Save changes'
              : 'Create event'}
        </button>
      </form>

      {message && (
        <div
          role="status"
          style={{
            padding: 14,
            borderRadius: 14,
            border: '1px solid #444',
            background: '#191919',
          }}
        >
          {message}
        </div>
      )}

      <section>
        <p
          style={{
            color: '#f5a623',
            fontWeight: 900,
          }}
        >
          EVENT CALENDAR
        </p>

        <h2>Published and draft events</h2>

        {loading ? (
          <p>Loading events...</p>
        ) : events.length === 0 ? (
          <div style={emptyStateStyle}>
            <CalendarDays size={34} />
            <h3>No events created yet</h3>
            <p>
              Create your first event using the form above.
            </p>
          </div>
        ) : (
          <div
            style={{
              display: 'grid',
              gap: 16,
            }}
          >
            {events.map((event) => (
              <article
                key={event.id}
                style={eventCardStyle}
              >
                {event.flyer_url ? (
                  <img
                    src={event.flyer_url}
                    alt={`${event.title} flyer`}
                    style={{
                      width: 110,
                      height: 140,
                      objectFit: 'cover',
                      borderRadius: 14,
                    }}
                  />
                ) : (
                  <div
                    style={{
                      width: 110,
                      height: 140,
                      borderRadius: 14,
                      background: '#222',
                      display: 'grid',
                      placeItems: 'center',
                    }}
                  >
                    <ImagePlus />
                  </div>
                )}

                <div style={{ flex: 1 }}>
                  <span
                    style={{
                      color: event.is_published
                        ? '#74d88b'
                        : '#f5a623',
                      fontWeight: 800,
                      fontSize: 13,
                    }}
                  >
                    {event.is_published
                      ? 'PUBLISHED'
                      : 'DRAFT'}
                  </span>

                  <h3>{event.title}</h3>

                  <p style={{ color: '#bbb' }}>
                    {event.event_date}
                    {event.start_time
                      ? ` · ${event.start_time.slice(0, 5)}`
                      : ''}
                  </p>

                  {event.admission && (
                    <p>{event.admission}</p>
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
                    onClick={() => editEvent(event)}
                    style={iconButtonStyle}
                    aria-label="Edit event"
                  >
                    <Pencil size={18} />
                  </button>

                  <button
                    type="button"
                    onClick={() => deleteEvent(event)}
                    style={{
                      ...iconButtonStyle,
                      color: '#ff7b7b',
                    }}
                    aria-label="Delete event"
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

const labelStyle: React.CSSProperties = {
  display: 'grid',
  gap: 8,
  fontWeight: 700,
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

const formGridStyle: React.CSSProperties = {
  display: 'grid',
  gap: 16,
  gridTemplateColumns:
    'repeat(auto-fit, minmax(220px, 1fr))',
  marginTop: 24,
};

const primaryButtonStyle: React.CSSProperties = {
  display: 'flex',
  justifyContent: 'center',
  alignItems: 'center',
  gap: 8,
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

const emptyStateStyle: React.CSSProperties = {
  padding: 30,
  border: '1px dashed #555',
  borderRadius: 20,
  textAlign: 'center',
  color: '#bbb',
};

const eventCardStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 18,
  padding: 18,
  border: '1px solid #333',
  borderRadius: 18,
  background: '#151515',
};