'use client';

import {
  Activity,
  AlertTriangle,
  ArrowUpRight,
  BarChart3,
  Bell,
  Bot,
  Boxes,
  Building2,
  CheckCircle2,
  ChevronDown,
  CircleDollarSign,
  CreditCard,
  LayoutDashboard,
  Menu,
  Package,
  ReceiptText,
  RefreshCw,
  Search,
  Settings,
  ShieldCheck,
  ShoppingCart,
  Sparkles,
  Target,
  TrendingUp,
  Users,
  WalletCards,
  X
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useState } from 'react';
import type { CommandCenterSnapshot, ExecutiveMetric, ExecutivePriority } from '@/lib/vivid-core/command-center/types';
import styles from './command-center.module.css';

const navigation = [
  { label: 'Overview', icon: LayoutDashboard, active: true },
  { label: 'Sales', icon: ShoppingCart },
  { label: 'Inventory', icon: Boxes },
  { label: 'Customers', icon: Users },
  { label: 'Employees', icon: Building2 },
  { label: 'Accounting', icon: ReceiptText },
  { label: 'Billing', icon: CreditCard },
  { label: 'AI Assistant', icon: Bot },
  { label: 'Reports', icon: BarChart3 },
  { label: 'Settings', icon: Settings }
];

const transactions = [
  { id: '#VIV-10482', customer: 'Walk-in customer', time: '11:42 PM', amount: '$84.00', status: 'Paid' },
  { id: '#VIV-10481', customer: 'Jasmine C.', time: '11:29 PM', amount: '$47.50', status: 'Paid' },
  { id: '#VIV-10480', customer: 'Marcus T.', time: '11:08 PM', amount: '$126.00', status: 'Paid' },
  { id: '#VIV-10479', customer: 'Walk-in customer', time: '10:54 PM', amount: '$35.00', status: 'Refunded' },
  { id: '#VIV-10478', customer: 'Nadia R.', time: '10:37 PM', amount: '$69.25', status: 'Paid' }
];

const inventory = [
  { name: 'Frozen Watermelon', stock: 6, target: 24 },
  { name: 'Strawberry Ice Cream', stock: 8, target: 20 },
  { name: 'Mint Premium', stock: 11, target: 30 },
  { name: 'Hookah Foil Packs', stock: 14, target: 40 }
];

const periodLabels: Record<CommandCenterSnapshot['period'], string> = {
  today: 'Today',
  week: 'This week',
  month: 'This month',
  quarter: 'This quarter',
  year: 'This year'
};

const metricIcons: Record<ExecutiveMetric['key'], typeof CircleDollarSign> = {
  net_sales: CircleDollarSign,
  transactions: WalletCards,
  active_members: Users,
  low_stock_items: Package
};

const priorityIcons: Record<ExecutivePriority['level'], typeof AlertTriangle> = {
  critical: AlertTriangle,
  growth: Target,
  review: ShieldCheck
};

function buildChart(series: CommandCenterSnapshot['salesSeries']) {
  if (!series.length) return { line: '', area: '' };
  const width = 700;
  const height = 230;
  const max = Math.max(...series.map((point) => point.amount), 1);
  const step = series.length === 1 ? 0 : width / (series.length - 1);
  const coordinates = series.map((point, index) => ({
    x: index * step,
    y: height - (point.amount / max) * (height - 18)
  }));
  const line = coordinates.map((point, index) => `${index === 0 ? 'M' : 'L'}${point.x.toFixed(1)},${point.y.toFixed(1)}`).join(' ');
  return { line, area: `${line} L${width},${height} L0,${height} Z` };
}

export default function CommandCenterPage() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [period, setPeriod] = useState<CommandCenterSnapshot['period']>('today');
  const [snapshot, setSnapshot] = useState<CommandCenterSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadSnapshot = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(`/api/v1/command-center?period=${period}`, {
        headers: { 'x-vivid-organization-id': 'vivid-technologies' },
        cache: 'no-store'
      });
      if (!response.ok) throw new Error(`Command Center API returned ${response.status}`);
      const payload = (await response.json()) as { data: CommandCenterSnapshot };
      setSnapshot(payload.data);
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Unable to load command center data.');
    } finally {
      setLoading(false);
    }
  }, [period]);

  useEffect(() => { void loadSnapshot(); }, [loadSnapshot]);

  const chart = useMemo(() => buildChart(snapshot?.salesSeries ?? []), [snapshot]);
  const netSales = snapshot?.metrics.find((metric) => metric.key === 'net_sales');

  return (
    <main className={styles.shell}>
      <aside className={`${styles.sidebar} ${mobileOpen ? styles.sidebarOpen : ''}`}>
        <div className={styles.brandRow}>
          <div className={styles.brandMark}>V+</div>
          <div><strong>VIVID+</strong><span>Enterprise</span></div>
          <button className={styles.mobileClose} onClick={() => setMobileOpen(false)} aria-label="Close menu"><X size={20} /></button>
        </div>
        <div className={styles.locationCard}>
          <div className={styles.locationIcon}><Building2 size={18} /></div>
          <div><span>Current location</span><strong>Vivid Lounge Orlando</strong></div>
          <ChevronDown size={16} />
        </div>
        <nav className={styles.nav} aria-label="Primary navigation">
          {navigation.map(({ label, icon: Icon, active }) => <button key={label} className={active ? styles.navActive : ''}><Icon size={18} /><span>{label}</span></button>)}
        </nav>
        <div className={styles.upgradeCard}>
          <Sparkles size={20} /><strong>Enterprise workspace</strong><p>Your POS, CRM, loyalty, inventory, accounting, and AI modules are connected.</p>
        </div>
        <div className={styles.userCard}><div className={styles.avatar}>AA</div><div><strong>Ali Abide</strong><span>Owner</span></div><ChevronDown size={16} /></div>
      </aside>

      {mobileOpen && <button className={styles.overlay} onClick={() => setMobileOpen(false)} aria-label="Close menu overlay" />}

      <section className={styles.content}>
        <header className={styles.topbar}>
          <div className={styles.topbarLeft}>
            <button className={styles.menuButton} onClick={() => setMobileOpen(true)} aria-label="Open menu"><Menu size={21} /></button>
            <div><p>Monday, July 27</p><h1>Executive Command Center</h1></div>
          </div>
          <div className={styles.topbarActions}>
            <label className={styles.searchBox}><Search size={17} /><input placeholder="Search VIVID+" aria-label="Search VIVID+" /></label>
            <button className={styles.iconButton} onClick={() => void loadSnapshot()} aria-label="Refresh command center"><RefreshCw size={18} /></button>
            <button className={styles.iconButton} aria-label="Notifications"><Bell size={19} /><i /></button>
            <button className={styles.newSaleButton}><ShoppingCart size={17} />New sale</button>
          </div>
        </header>

        <div className={styles.pageBody}>
          <section className={styles.hero}>
            <div><span className={styles.eyebrow}>LIVE BUSINESS COMMAND CENTER</span><h2>Good evening, Ali.</h2><p>{loading ? 'Synchronizing your business intelligence…' : `Updated ${snapshot ? new Date(snapshot.generatedAt).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }) : 'just now'}.`}</p></div>
            <select className={styles.dateButton} value={period} onChange={(event) => setPeriod(event.target.value as CommandCenterSnapshot['period'])} aria-label="Reporting period">
              {Object.entries(periodLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
          </section>

          {error && <article className={styles.metricCard} role="alert"><div className={styles.metricTop}><span>Live data connection</span><div className={styles.metricIconWarning}><AlertTriangle size={19} /></div></div><strong>Unable to refresh</strong><div className={styles.metricBottom}><span className={styles.warningText}>{error}</span></div></article>}

          <section className={styles.executiveGrid}>
            <article className={styles.healthCard}>
              <div className={styles.healthSummary}>
                <div><span className={styles.cardEyebrow}>BUSINESS HEALTH</span><div className={styles.healthScore}><strong>{snapshot?.health.score ?? '—'}</strong><span>/100</span></div><p><CheckCircle2 size={15} /> {snapshot ? `${snapshot.health.status} · ${snapshot.health.weeklyChange >= 0 ? 'up' : 'down'} ${Math.abs(snapshot.health.weeklyChange)} points this week` : 'Loading live health score'}</p></div>
                <div className={styles.healthRing} style={{ background: `conic-gradient(#c89d2f 0 ${snapshot?.health.score ?? 0}%, #eceff2 ${snapshot?.health.score ?? 0}% 100%)` }} aria-label={`Business health score ${snapshot?.health.score ?? 0} out of 100`}><span>{snapshot?.health.score ?? 0}%</span></div>
              </div>
              <div className={styles.healthFactors}>{(snapshot?.health.factors ?? []).map((factor) => <div key={factor.key} className={styles.healthFactor}><div><span>{factor.label}</span><strong>{factor.score}</strong></div><div className={styles.healthTrack}><i style={{ width: `${factor.score}%` }} /></div></div>)}</div>
            </article>

            <article className={styles.priorityCard}>
              <div className={styles.panelHeader}><div><span>Executive focus</span><strong>Today&apos;s priorities</strong></div><button>View plan <ArrowUpRight size={15} /></button></div>
              <div className={styles.priorityList}>{(snapshot?.priorities ?? []).map((priority) => { const Icon = priorityIcons[priority.level]; return <button key={priority.id} className={styles.priorityItem}><div className={styles.priorityIcon}><Icon size={17} /></div><div><strong>{priority.title}</strong><span>{priority.estimatedImpact ?? priority.detail}</span></div><small>{priority.level}</small><ArrowUpRight size={15} /></button>; })}</div>
            </article>
          </section>

          <section className={styles.metricGrid}>{(snapshot?.metrics ?? []).map((metric) => { const Icon = metricIcons[metric.key]; const change = metric.changePercent === undefined ? (metric.requiresAction ? 'Needs action' : 'Live') : `${metric.changePercent >= 0 ? '+' : ''}${metric.changePercent}%`; return <article key={metric.key} className={styles.metricCard}><div className={styles.metricTop}><span>{metric.label}</span><div className={metric.requiresAction ? styles.metricIconWarning : styles.metricIcon}><Icon size={19} /></div></div><strong>{metric.formattedValue}</strong><div className={styles.metricBottom}><span className={metric.requiresAction ? styles.warningText : styles.positiveText}>{change}</span><small>{metric.detail}</small></div></article>; })}</section>

          <section className={styles.mainGrid}>
            <article className={styles.panelLarge}>
              <div className={styles.panelHeader}><div><span>Sales performance</span><strong>{netSales?.formattedValue ?? '—'}</strong></div><button>View report <ArrowUpRight size={15} /></button></div>
              <div className={styles.chartWrap}><div className={styles.yAxis}><span>$8k</span><span>$6k</span><span>$4k</span><span>$2k</span><span>$0</span></div><div className={styles.chartArea}><div className={styles.gridLine} /><div className={styles.gridLine} /><div className={styles.gridLine} /><div className={styles.gridLine} /><div className={styles.gridLine} /><svg viewBox="0 0 700 230" preserveAspectRatio="none" aria-label="Live sales trend chart"><defs><linearGradient id="salesArea" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="currentColor" stopOpacity="0.28" /><stop offset="100%" stopColor="currentColor" stopOpacity="0" /></linearGradient></defs><path className={styles.chartFill} d={chart.area} /><path className={styles.chartLine} d={chart.line} /></svg><div className={styles.xAxis}>{(snapshot?.salesSeries ?? []).map((point) => <span key={point.timestamp}>{point.timestamp}</span>)}</div></div></div>
            </article>
            <article className={styles.aiPanel}><div className={styles.aiBadge}><Bot size={18} /> VIVID AI · {snapshot?.aiBrief.confidence ?? 0}% CONFIDENCE</div><h3>{snapshot?.aiBrief.headline ?? 'Executive intelligence loading'}</h3><p>{snapshot?.aiBrief.observation ?? 'VIVID AI is analyzing your business performance.'}</p><div className={styles.insightStat}><TrendingUp size={18} /><div><strong>{snapshot?.aiBrief.expectedImpact ?? 'Calculating impact'}</strong><span>{snapshot?.aiBrief.recommendation ?? 'Preparing recommendation'}</span></div></div><button>{snapshot?.aiBrief.requiresApproval ? 'Review recommendation' : 'Open executive brief'} <ArrowUpRight size={16} /></button></article>
          </section>

          <section className={styles.bottomGrid}>
            <article className={styles.tablePanel}><div className={styles.panelHeader}><div><span>Recent activity</span><strong>Latest transactions</strong></div><button>View all <ArrowUpRight size={15} /></button></div><div className={styles.tableWrap}><table><thead><tr><th>Transaction</th><th>Customer</th><th>Time</th><th>Status</th><th>Amount</th></tr></thead><tbody>{transactions.map((transaction) => <tr key={transaction.id}><td>{transaction.id}</td><td>{transaction.customer}</td><td>{transaction.time}</td><td><span className={transaction.status === 'Paid' ? styles.statusPaid : styles.statusRefunded}>{transaction.status}</span></td><td>{transaction.amount}</td></tr>)}</tbody></table></div></article>
            <article className={styles.inventoryPanel}><div className={styles.panelHeader}><div><span>Inventory alerts</span><strong>Low stock</strong></div><button aria-label="Open inventory activity"><Activity size={16} /></button></div><div className={styles.inventoryList}>{inventory.map((item) => <div key={item.name} className={styles.inventoryItem}><div><strong>{item.name}</strong><span>{item.stock} units remaining</span></div><div className={styles.progressTrack}><i style={{ width: `${Math.max(10, (item.stock / item.target) * 100)}%` }} /></div></div>)}</div><button className={styles.inventoryButton}>Open inventory</button></article>
          </section>
        </div>
      </section>
    </main>
  );
}
