export function calculateBusinessHealth(metrics: {
  revenue: number;
  customers: number;
  inventory: number;
  marketing: number;
  finance: number;
}) {
  return Math.round(
    metrics.revenue * 0.30 +
      metrics.customers * 0.20 +
      metrics.inventory * 0.15 +
      metrics.marketing * 0.15 +
      metrics.finance * 0.20
  );
}