import { Gift, MapPin, PartyPopper, WalletCards } from "lucide-react";

const actions = [
  { icon: WalletCards, title: "Digital card", copy: "Keep your membership ready" },
  { icon: MapPin, title: "Directions", copy: "7216 W Colonial Dr" },
  { icon: PartyPopper, title: "Events", copy: "See what is happening tonight" },
  { icon: Gift, title: "Refer a friend", copy: "Earn bonus points together" },
];

type Props = {
  onCard: () => void;
  onEvents: () => void;
};

export function QuickActions({ onCard, onEvents }: Props) {
  return (
    <section className="quick-grid">
      {actions.map(({ icon: Icon, title, copy }) => (
        <button
          key={title}
          className="quick-action"
          onClick={
            title === "Digital card"
              ? onCard
              : title === "Events"
              ? onEvents
              : undefined
          }
        >
          <Icon />
          <b>{title}</b>
          <span>{copy}</span>
        </button>
      ))}
    </section>
  );
}