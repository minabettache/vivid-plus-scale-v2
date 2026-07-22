import { BadgePercent, Sparkles, Ticket, Utensils } from 'lucide-react';

export function FeaturedOffer() {
  return <section className="section"><div className="section-head"><div><p className="eyebrow small">TODAY&apos;S EXCLUSIVE</p><h3>Featured offer</h3></div><span>Member only</span></div><article className="featured-offer"><div><p>DOUBLE POINTS</p><h3>Earn 2× points on eligible food, games, and lounge experiences today.</h3><button>Activate offer</button></div><Sparkles size={64} /></article></section>;
}

export function OffersPanel() {
  const offers = [
    { icon: BadgePercent, label: 'BONUS POINTS', title: 'Earn 150 bonus points on eligible merchandise.', meta: 'Expires Sunday' },
    { icon: Utensils, label: 'FOOD & CAFÉ', title: '$5 reward after two qualifying visits.', meta: 'Member exclusive' },
    { icon: Ticket, label: 'EVENT ACCESS', title: 'Early RSVP access for this weekend.', meta: 'Limited availability' }
  ];
  return <section className="section page-section"><div className="section-head"><div><p className="eyebrow small">PERSONALIZED FOR YOU</p><h3>Your offers</h3></div><span>{offers.length} available</span></div><div className="offer-list">{offers.map(({ icon: Icon, label, title, meta }) => <article className="offer" key={title}><div className="icon-box"><Icon /></div><div><p>{label}</p><h3>{title}</h3><span>{meta}</span></div></article>)}</div></section>;
}
