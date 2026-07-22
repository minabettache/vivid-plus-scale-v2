import { CalendarDays, ChevronRight, Clock3 } from 'lucide-react';
import { events } from '@/lib/data';

export function EventsPanel() {
  return <section className="section page-section"><div className="section-head"><div><p className="eyebrow small">UPCOMING AT VIVID</p><h3>Events</h3></div><span>Orlando</span></div><div className="event-list">{events.map((event) => <article className="event-card" key={event.title}><div className="event-date"><b>{event.day}</b><strong>{event.date}</strong></div><div className="event-copy"><span>{event.tag}</span><h3>{event.title}</h3><p><Clock3 size={14} /> {event.time}</p></div><ChevronRight /></article>)}</div><button className="secondary full"><CalendarDays size={17} /> View complete calendar</button></section>;
}
