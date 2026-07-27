import type { CommandCenterSnapshot } from './types';

const allowedPeriods = new Set(['today', 'week', 'month', 'quarter', 'year']);

export function normalizePeriod(value: string | null): CommandCenterSnapshot['period'] {
  return value && allowedPeriods.has(value)
    ? (value as CommandCenterSnapshot['period'])
    : 'today';
}

export async function getCommandCenterSnapshot(input: {
  organizationId: string;
  locationId: string;
  period: CommandCenterSnapshot['period'];
}): Promise<CommandCenterSnapshot> {
  const { organizationId, locationId, period } = input;

  // This is the first stable application contract for the command center.
  // The data is intentionally isolated behind a service so Supabase queries can
  // replace this seed implementation without changing the API response shape.
  return {
    generatedAt: new Date().toISOString(),
    organizationId,
    locationId,
    period,
    health: {
      score: 92,
      status: 'excellent',
      weeklyChange: 3,
      factors: [
        { key: 'revenue', label: 'Revenue', score: 96 },
        { key: 'customers', label: 'Customer loyalty', score: 91 },
        { key: 'operations', label: 'Operations', score: 88 },
        { key: 'inventory', label: 'Inventory', score: 76 }
      ]
    },
    metrics: [
      {
        key: 'net_sales',
        label: 'Net sales',
        value: 18420,
        formattedValue: '$18,420.00',
        changePercent: 12.4,
        trend: 'up',
        detail: 'vs. previous period'
      },
      {
        key: 'transactions',
        label: 'Transactions',
        value: 482,
        formattedValue: '482',
        changePercent: 8.1,
        trend: 'up',
        detail: 'average ticket $38.22'
      },
      {
        key: 'active_members',
        label: 'Active members',
        value: 1284,
        formattedValue: '1,284',
        trend: 'up',
        detail: '34 new this month'
      },
      {
        key: 'low_stock_items',
        label: 'Low-stock items',
        value: 17,
        formattedValue: '17',
        trend: 'flat',
        detail: '4 critical items',
        requiresAction: true
      }
    ],
    priorities: [
      {
        id: 'inventory-charcoal-reorder',
        title: 'Reorder coconut charcoal',
        detail: 'Projected stockout in 2 days',
        level: 'critical',
        actionLabel: 'Create purchase order'
      },
      {
        id: 'growth-tuesday-traffic',
        title: 'Launch Tuesday traffic campaign',
        detail: 'Premium upgrade audience is ready',
        level: 'growth',
        actionLabel: 'Review campaign',
        estimatedImpact: '+$1,420 weekly revenue'
      },
      {
        id: 'risk-refund-review',
        title: 'Review refunded transaction',
        detail: '#VIV-10479 · $35.00',
        level: 'review',
        actionLabel: 'Open transaction'
      }
    ],
    aiBrief: {
      headline: "Tonight's opportunity",
      observation: 'Premium hookah sales are outperforming classic hookahs by 26% after 9 PM.',
      recommendation: 'Promote premium upgrades to eligible customers after 9 PM.',
      expectedImpact: '+$486 estimated nightly upside',
      confidence: 89,
      requiresApproval: true
    },
    salesSeries: [
      { timestamp: '08:00', amount: 1400 },
      { timestamp: '11:00', amount: 3200 },
      { timestamp: '14:00', amount: 4800 },
      { timestamp: '17:00', amount: 6100 },
      { timestamp: '20:00', amount: 7400 },
      { timestamp: '00:00', amount: 7800 }
    ]
  };
}
