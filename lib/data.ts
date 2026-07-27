import { CupSoda, Flame, Gift } from 'lucide-react';

export const rewards = [
  {
    points: 500,
    title: 'Free drink',
    subtitle: 'Redeem one eligible drink at Vivid Lounge',
    icon: CupSoda,
  },
  {
    points: 1000,
    title: 'Free hookah',
    subtitle: 'Redeem one classic hookah at Vivid Lounge',
    icon: Flame,
  },
  {
    points: 1400,
    title: 'Free drink + free hookah',
    subtitle: 'Redeem one eligible drink and one classic hookah',
    icon: Gift,
  },
];

export const events: {
  day: string;
  date: string;
  title: string;
  time: string;
  tag: string;
}[] = [];

export const interests = ['Lounge', 'Events'] as const;