'use client';

import {
  CalendarDays,
  Clock3,
  ImagePlus,
  LoaderCircle,
  Music2,
  Ticket,
} from 'lucide-react';
import { useEffect, useState } from 'react';

type VividEvent = {
  id: string;
  title: string;
  description: string | null;
  event_date: string;
  start_time: string | null;
  end_time: string | null;
  flyer_url: string | null;
  tag: string;
  dj: string | null;
  admission: string | null;
};

function formatEventDate(date: string) {
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(`${date}T12:00:00Z`));
}

function formatTime(time: string | null) {
  if (!time) {
    return '';
  }

  const [hourValue, minuteValue] = time.split(':');
  const date = new Date();

  date.setHours(Number(hourValue), Number(minuteValue));

  return new Intl.DateTimeFormat('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

export function EventsPanel() {
  const [events, setEvents] = useState<VividEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  useEffect(() => {
    async function loadEvents() {
      try {
        const response = await fetch('/api/events', {
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

    void loadEvents();
  }, []);

  return (
    <section className="section page-section">
      <div className="section-head">
        <div>
          <p className="eyebrow small">
            UPCOMING AT VIVID
          </p>

          <h3>Events</h3>
        </div>

        <span>Orlando</span>
      </div>

      {loading ? (
        <article className="offer">
          <div className="icon-box">
            <LoaderCircle />
          </div>

          <div>
            <p>EVENT CALENDAR</p>
            <h3>Loading Vivid events...</h3>
          </div>
        </article>
      ) : message ? (
        <article className="offer">
          <div className="icon-box">
            <CalendarDays />
          </div>

          <div>
            <p>EVENT CALENDAR</p>
            <h3>{message}</h3>
          </div>
        </article>
      ) : events.length === 0 ? (
        <article className="offer">
          <div className="icon-box">
            <CalendarDays />
          </div>

          <div>
            <p>EVENT CALENDAR</p>
            <h3>No upcoming events published yet.</h3>

            <span>
              New events will appear here automatically.
            </span>
          </div>
        </article>
      ) : (
        <div
          style={{
            display: 'grid',
            gap: 20,
          }}
        >
          {events.map((event) => (
            <article
              key={event.id}
              className="offer"
              style={{
                alignItems: 'flex-start',
              }}
            >
              {event.flyer_url ? (
                <img
                  src={event.flyer_url}
                  alt={`${event.title} flyer`}
                  style={{
                    width: 120,
                    maxWidth: '34%',
                    aspectRatio: '4 / 5',
                    objectFit: 'cover',
                    borderRadius: 16,
                  }}
                />
              ) : (
                <div className="icon-box">
                  <ImagePlus />
                </div>
              )}

              <div>
                <p>{event.tag}</p>

                <h3>{event.title}</h3>

                <span>
                  <CalendarDays size={14} />{' '}
                  {formatEventDate(event.event_date)}
                </span>

                {event.start_time && (
                  <span
                    style={{
                      display: 'block',
                      marginTop: 8,
                    }}
                  >
                    <Clock3 size={14} />{' '}
                    {formatTime(event.start_time)}
                    {event.end_time
                      ? ` – ${formatTime(event.end_time)}`
                      : ''}
                  </span>
                )}

                {event.dj && (
                  <span
                    style={{
                      display: 'block',
                      marginTop: 8,
                    }}
                  >
                    <Music2 size={14} /> {event.dj}
                  </span>
                )}

                {event.admission && (
                  <span
                    style={{
                      display: 'block',
                      marginTop: 8,
                    }}
                  >
                    <Ticket size={14} /> {event.admission}
                  </span>
                )}

                {event.description && (
                  <p
                    style={{
                      marginTop: 12,
                      lineHeight: 1.6,
                    }}
                  >
                    {event.description}
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