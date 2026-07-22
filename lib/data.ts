import { PartyPopper, Sparkles, Ticket, Utensils } from "lucide-react";

export const rewards = [
  {
    points: 250,
    title: "Free game credit",
    subtitle: "One complimentary game credit",
    icon: Ticket,
  },
  {
    points: 500,
    title: "$5 café credit",
    subtitle: "Use toward eligible food or café items",
    icon: Utensils,
  },
  {
    points: 800,
    title: "Lounge upgrade",
    subtitle: "Upgrade an eligible lounge experience",
    icon: Sparkles,
  },
  {
    points: 1200,
    title: "Premium event entry",
    subtitle: "Admission to one eligible Vivid event",
    icon: PartyPopper,
  },
];

export const events = [
  {
    day: "WED",
    date: "22",
    title: "R&B + Game Night",
    time: "10 PM",
    tag: "Weekly",
  },
  {
    day: "FRI",
    date: "24",
    title: "Vivid Friday Experience",
    time: "10 PM",
    tag: "Featured",
  },
  {
    day: "SAT",
    date: "25",
    title: "Late Night at Vivid",
    time: "10 PM",
    tag: "VIP Access",
  },
];

export const interests = [
  "Lounge",
  "Events",
  "Games",
  "Food Partner",
  "Retail & Merch",
] as const;