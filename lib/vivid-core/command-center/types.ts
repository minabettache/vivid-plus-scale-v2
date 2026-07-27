export type HealthStatus = 'excellent' | 'healthy' | 'attention' | 'critical';
export type PriorityLevel = 'critical' | 'growth' | 'review';
export type TrendDirection = 'up' | 'down' | 'flat';

export type HealthFactor = {
  key: 'revenue' | 'customers' | 'operations' | 'inventory';
  label: string;
  score: number;
};

export type ExecutiveMetric = {
  key: 'net_sales' | 'transactions' | 'active_members' | 'low_stock_items';
  label: string;
  value: number;
  formattedValue: string;
  changePercent?: number;
  trend: TrendDirection;
  detail: string;
  requiresAction?: boolean;
};

export type ExecutivePriority = {
  id: string;
  title: string;
  detail: string;
  level: PriorityLevel;
  actionLabel: string;
  estimatedImpact?: string;
};

export type AiExecutiveBrief = {
  headline: string;
  observation: string;
  recommendation: string;
  expectedImpact: string;
  confidence: number;
  requiresApproval: boolean;
};

export type SalesPoint = {
  timestamp: string;
  amount: number;
};

export type CommandCenterSnapshot = {
  generatedAt: string;
  organizationId: string;
  locationId: string;
  period: 'today' | 'week' | 'month' | 'quarter' | 'year';
  health: {
    score: number;
    status: HealthStatus;
    weeklyChange: number;
    factors: HealthFactor[];
  };
  metrics: ExecutiveMetric[];
  priorities: ExecutivePriority[];
  aiBrief: AiExecutiveBrief;
  salesSeries: SalesPoint[];
};
