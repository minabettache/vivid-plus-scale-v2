export function executiveBrief(input: {
  revenueToday: number;
  revenueYesterday: number;
}) {
  const change =
    ((input.revenueToday - input.revenueYesterday) /
      input.revenueYesterday) *
    100;

  return {
    title: "Executive Brief",
    message:
      change > 0
        ? `Revenue increased ${change.toFixed(1)}% today.`
        : `Revenue decreased ${Math.abs(change).toFixed(1)}%.`,
    confidence: 92,
  };
}