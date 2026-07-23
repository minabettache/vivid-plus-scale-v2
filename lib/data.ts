import {
  Armchair,
  CupSoda,
  Crown,
  RefreshCw,
  Sparkles,
  Ticket,
} from "lucide-react";

export const rewards = [
  {
    points: 250,
    title: "Free non-alcoholic drink",
    subtitle: "Choose one eligible VIVID lounge drink",
    icon: CupSoda,
  },
  {
    points: 400,
    title: "Hookah refill",
    subtitle: "One eligible hookah flavor refill",
    icon: RefreshCw,
  },
  {
    points: 650,
    title: "VIP seating upgrade",
    subtitle: "Upgrade to eligible VIP lounge seating",
    icon: Armchair,
  },
  {
    points: 900,
    title: "Free hookah",
    subtitle: "One eligible classic lounge hookah",
    icon: Sparkles,
  },
  {
    points: 1200,
    title: "Premium event entry",
    subtitle: "Admission to one eligible VIVID event",
    icon: Ticket,
  },
  {
    points: 1800,
    title: "VIP lounge experience",
    subtitle: "Exclusive VIVID member lounge experience",
    icon: Crown,
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