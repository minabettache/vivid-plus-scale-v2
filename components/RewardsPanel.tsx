import { rewards } from '@/lib/data';

export function RewardsPanel({ points }: { points: number }) {
  return <section className="section page-section"><div className="section-head"><div><p className="eyebrow small">REDEEM YOUR POINTS</p><h3>Reward store</h3></div><span>{points} points</span></div><div className="reward-list">{rewards.map(({ points: cost, title, subtitle, icon: Icon }) => <article className="reward" key={title}><div className="icon-box"><Icon /></div><div><h3>{title}</h3><span>{subtitle} · {cost} points</span></div><button disabled={points < cost}>{points >= cost ? 'Redeem' : 'Locked'}</button></article>)}</div></section>;
}
