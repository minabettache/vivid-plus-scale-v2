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
import { useEffect, useState } from 'react';
import type { CommandCenterSnapshot } from '@/lib/vivid-core/command-center/types';
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

const metricIcons = {
  net_sales: CircleDollarSign,
  transactions: WalletCards,
  active_members: Users,
  low_stock_items: Package
} as const;

const priorityIcons = {
  critical: AlertTriangle,
  growth: Target,
  review: ShieldCheck
} as const;

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

export default function CommandCenterPage() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [snapshot, setSnapshot] = useState<CommandCenterSnapshot | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const controller = new AbortController();

    async function loadCommandCenter() {
      try {
        const response = await fetch('/api/v1/command-center?period=today', {
          signal: controller.signal,
          cache: 'no-store'
        });

        if (!response.ok) {
          throw new Error(`Unable to load command center (${response.status})`);
        }

        const payload = (await response.json()) as { data: CommandCenterSnapshot };
        setSnapshot(payload.data);
      } catch (requestError) {
        if ((requestError as Error).name !== 'AbortError') {
          setError((requestError as Error).message);
        }
      }
    }

    loadCommandCenter();
    return () => controller.abort();
  }, []);

  const healthScore = snapshot?.health.score ?? 0;
  const healthStatus = snapshot?.health.status ?? 'healthy';
  const weeklyChange = snapshot?.health.weeklyChange ?? 0;

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
          {navigation.map(({ label, icon: Icon, active }) => (
            <button key={label} className={active ? styles.navActive : ''}><Icon size={18} /><span>{label}</span></button>
          ))}
        </nav>

        <div className={styles.upgradeCard}>
          <Sparkles size={20} />
          <strong>Enterprise workspace</strong>
          <p>Your POS, CRM, loyalty, inventory, accounting, and AI modules are connected.</p>
        </div>

        <div className={styles.userCard}>
          <div className={styles.avatar}>AA</div>
          <div><strong>Ali Abide</strong><span>Owner</span></div>
          <ChevronDown size={16} />
        </div>
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
            <button className={styles.iconButton} aria-label="Notifications"><Bell size={19} /><i /></button>
            <button className={styles.newSaleButton}><ShoppingCart size={17} />New sale</button>
          </div>
        </header>

        <div className={styles.pageBody}>
          <section className={styles.hero}>
            <div>
              <span className={styles.eyebrow}>LIVE BUSINESS COMMAND CENTER</span>
              <h2>Good evening, Ali.</h2>
              <p>{error ? error : snapshot ? 'Live executive intelligence is connected.' : 'Loading live executive intelligence...'}</p>
            </div>
            <button className={styles.dateButton}>Today <ChevronDown size={16} /></button>
          </section>

          <section className={styles.executiveGrid}>
            <article className={styles.healthCard}>
              <div className={styles.healthSummary}>
                <div>
                  <span className={styles.cardEyebrow}>BUSINESS HEALTH</span>
                  <div className={styles.healthScore}><strong>{snapshot ? healthScore : '--'}</strong><span>/100</span></div>
                  <p><CheckCircle2 size={15} /> {healthStatus} · {weeklyChange >= 0 ? 'up' : 'down'} {Math.abs(weeklyChange)} points this week</p>
                </div>
                <div
                  className={styles.healthRing}
                  aria-label={`Business health score ${healthScore} out of 100`}
                  style={{ background: `conic-gradient(#c89d2f 0 ${healthScore}%, #eceff2 ${healthScore}% 100%)` }}
                >
                  <span>{snapshot ? `${healthScore}%` : '--'}</span>
                </div>
              </div>
              <div className={styles.healthFactors}>
                {(snapshot?.health.factors ?? []).map((factor) => (
                  <div key={factor.key} className={styles.healthFactor}>
                    <div><span>{factor.label}</span><strong>{factor.score}</strong></div>
                    <div className={styles.healthTrack}><i style={{ width: `${factor.score}%` }} /></div>
                  </div>
                ))}
              </div>
            </article>

            <article className={styles.priorityCard}>
              <div className={styles.panelHeader}>
                <div><span>Executive focus</span><strong>Today&apos;s priorities</strong></div>
                <button>View plan <ArrowUpRight size={15} /></button>
              </div>
              <div className={styles.priorityList}>
                {(snapshot?.priorities ?? []).map((priority) => {
                  const Icon = priorityIcons[priority.level];
                  return (
                    <button key={priority.id} className={styles.priorityItem}>
                      <div className={styles.priorityIcon}><Icon size={17} /></div>
                      <div><strong>{priority.title}</strong><span>{priority.detail}</span></div>
                      <small>{priority.level}</small>
                      <ArrowUpRight size={15} />
                    </button>
                  );
                })}
              </div>
            </article>
          </section>

          <section className={styles.metricGrid}>
            {(snapshot?.metrics ?? []).map((metric) => {
              const Icon = metricIcons[metric.key];
              const warning = metric.requiresAction;
              const change = metric.changePercent === undefined
                ? (warning ? 'Needs action' : 'Live')
                : `${metric.changePercent >= 0 ? '+' : ''}${metric.changePercent}%`;

              return (
                <article key={metric.key} className={styles.metricCard}>
                  <div className={styles.metricTop}><span>{metric.label}</span><div className={warning ? styles.metricIconWarning : styles.metricIcon}><Icon size={19} /></div></div>
                  <strong>{metric.formattedValue}</strong>
                  <div className={styles.metricBottom}><span className={warning ? styles.warningText : styles.positiveText}>{change}</span><small>{metric.detail}</small></div>
                </article>
              );
            })}
          </section>

          <section className={styles.mainGrid}>
            <article className={styles.panelLarge}>
              <div className={styles.panelHeader}><div><span>Sales performance</span><strong>{snapshot?.metrics.find((metric) => metric.key === 'net_sales')?.formattedValue ?? '--'}</strong></div><button>View report <ArrowUpRight size={15} /></button></div>
              <div className={styles.chartWrap}>
                <div className={styles.yAxis}><span>$8k</span><span>$6k</span><span>$4k</span><span>$2k</span><span>$0</span></div>
                <div className={styles.chartArea}>
                  <div className={styles.gridLine} /><div className={styles.gridLine} /><div className={styles.gridLine} /><div className={styles.gridLine} /><div className={styles.gridLine} />
                  <svg viewBox="0 0 700 230" preserveAspectRatio="none" aria-label="Sales trend chart">
                    <defs><linearGradient id="salesArea" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="currentColor" stopOpacity="0.28" /><stop offset="100%" stopColor="currentColor" stopOpacity="0" /></linearGradient></defs>
                    <path className={styles.chartFill} d="M0,184 C55,169 78,178 125,147 C170,116 206,135 249,107 C295,76 325,101 368,71 C410,45 451,65 493,39 C540,12 572,31 610,18 C650,5 678,19 700,11 L700,230 L0,230 Z" />
                    <path className={styles.chartLine} d="M0,184 C55,169 78,178 125,147 C170,116 206,135 249,107 C295,76 325,101 368,71 C410,45 451,65 493,39 C540,12 572,31 610,18 C650,5 678,19 700,11" />
                  </svg>
                  <div className={styles.xAxis}><span>8 AM</span><span>11 AM</span><span>2 PM</span><span>5 PM</span><span>8 PM</span><span>12 AM</span></div>
                </div>
              </div>
            </article>

            <article className={styles.aiPanel}>
              <div className={styles.aiBadge}><Bot size={18} /> VIVID AI</div>
              <h3>{snapshot?.aiBrief.headline ?? 'Executive brief'}</h3>
              <p>{snapshot?.aiBrief.observation ?? 'Loading your latest business insight...'}</p>
              <div className={styles.insightStat}><TrendingUp size={18} /><div><strong>{snapshot?.aiBrief.expectedImpact ?? '--'}</strong><span>{snapshot?.aiBrief.recommendation ?? 'Preparing recommendation'}</span></div></div>
              <button>Review recommendation <ArrowUpRight size={16} /></button>
            </article>
          </section>

          <section className={styles.bottomGrid}>
            <article className={styles.tablePanel}>
              <div className={styles.panelHeader}><div><span>Recent activity</span><strong>Latest transactions</strong></div><button>View all <ArrowUpRight size={15} /></button></div>
              <div className={styles.tableWrap}>
                <table><thead><tr><th>Transaction</th><th>Customer</th><th>Time</th><th>Status</th><th>Amount</th></tr></thead>
                  <tbody>{transactions.map((transaction) => (
                    <tr key={transaction.id}><td>{transaction.id}</td><td>{transaction.customer}</td><td>{transaction.time}</td><td><span className={transaction.status === 'Paid' ? styles.statusPaid : styles.statusRefunded}>{transaction.status}</span></td><td>{transaction.amount}</td></tr>
                  ))}</tbody>
                </table>
              </div>
            </article>

            <article className={styles.inventoryPanel}>
              <div className={styles.panelHeader}><div><span>Inventory alerts</span><strong>Low stock</strong></div><button><Activity size={16} /></button></div>
              <div className={styles.inventoryList}>{inventory.map((item) => (
                <div key={item.name} className={styles.inventoryItem}><div><strong>{item.name}</strong><span>{item.stock} units remaining</span></div><div className={styles.progressTrack}><i style={{ width: `${Math.max(10, (item.stock / item.target) * 100)}%` }} /></div></div>
              ))}</div>
              <button className={styles.inventoryButton}>Open inventory</button>
            </article>
          </section>
        </div>
      </section>
    </main>
  );
}
