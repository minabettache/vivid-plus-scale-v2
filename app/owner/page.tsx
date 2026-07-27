"use client";

"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Activity, CalendarDays, CircleDollarSign, Clock3, CreditCard, Gift,
  Loader2, RefreshCw, Sparkles, TicketCheck, TrendingDown, TrendingUp,
  Trophy, Users, WalletCards, X
} from "lucide-react";
import {
  Area, AreaChart, CartesianGrid, Cell, Pie, PieChart,
  ResponsiveContainer, Tooltip, XAxis, YAxis
} from "recharts";

import BusinessPulse from "./components/BusinessPulse";

type Summary = {
  revenueToday: number; salesToday: number; visitsToday: number;
  uniqueVisitorsToday: number; averageTicket: number; pointsAwardedToday: number;
  totalMembers: number; activeMembers: number; newMembersToday: number;
  activePromotions: number; upcomingEvents: number; rewardRedemptionsToday: number;
};

type Sale = {
  id: string; memberId: string | null; memberName: string; amount: number;
  pointsEarned: number; paymentMethod: string; tier: string | null;
  note: string | null; createdAt: string | null;
};

type Promotion = {
  id?: string | number; name?: string | null; title?: string | null;
  description?: string | null; promotion_type?: string | null;
  discount_price?: number | string | null; terms?: string | null;
};

type EventRow = {
  id?: string | number; title?: string | null; name?: string | null;
  starts_at?: string | null; start_at?: string | null; event_at?: string | null;
  event_date?: string | null; date?: string | null;
};

type Redemption = {
  id?: string | number; reward_name?: string | null; title?: string | null;
  points_spent?: number | string | null; created_at?: string | null;
  redeemed_at?: string | null;
};

type DashboardResponse = {
  generatedAt: string; timezone: string; businessDayCutoffHour: number;
  businessDay: string; owner: { id: string; role: string }; summary: Summary;
  latestSales: Sale[]; activePromotions: Promotion[];
  upcomingEvents: EventRow[]; recentRedemptions: Redemption[];
};

type AnalyticsResponse = {
  generatedAt: string; timezone: string; businessDayCutoffHour: number;
  businessDay: string;
  comparison: {
    revenueToday: number; revenueYesterday: number;
    difference: number; percentageChange: number;
  };
  hourlySales: { hour: number; label: string; revenue: number; sales: number }[];
  paymentMethods: {
    cash: { revenue: number; sales: number };
    card: { revenue: number; sales: number };
    digitalWallet: { revenue: number; sales: number };
    other: { revenue: number; sales: number };
  };
  topMembers: {
    rank: number; memberId: string; memberName: string;
    revenue: number; visits: number; pointsEarned: number;
  }[];
  dailyTrend: {
    businessDay: string; label: string; revenue: number; sales: number;
  }[];
};

const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });
const whole = new Intl.NumberFormat("en-US");
const PAYMENT_COLORS = ["#d946ef", "#8b5cf6", "#22c55e", "#71717a"];
const DAILY_REVENUE_GOAL = Number(process.env.NEXT_PUBLIC_DAILY_REVENUE_GOAL ?? 1000);

function formatMoney(value: number) {
  return money.format(Number.isFinite(value) ? value : 0);
}

function titleCase(value?: string | null) {
  if (!value) return "Unknown";
  return value.replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function formatTime(value?: string | null) {
  if (!value) return "Time unavailable";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Time unavailable";
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York", hour: "numeric", minute: "2-digit"
  }).format(date);
}

function formatDateTime(value?: string | null) {
  if (!value) return "Date to be announced";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York", month: "short", day: "numeric",
    hour: "numeric", minute: "2-digit"
  }).format(date);
}

function eventDate(event: EventRow) {
  return event.starts_at ?? event.start_at ?? event.event_at ??
    event.event_date ?? event.date ?? null;
}

function eventName(event: EventRow) {
  return event.title || event.name || "VIVID+ Event";
}

function promotionName(promotion: Promotion) {
  return promotion.name || promotion.title || "VIVID+ Promotion";
}

function initials(name: string) {
  return name.split(" ").filter(Boolean).map((part) => part[0]).join("")
    .slice(0, 2).toUpperCase();
}

function StatCard({ label, value, detail, icon: Icon }: {
  label: string; value: string; detail: string; icon: typeof Activity;
}) {
  return (
    <article className="group relative overflow-hidden rounded-3xl border border-white/10 bg-white/[0.045] p-5 shadow-2xl shadow-black/10 backdrop-blur-xl transition hover:-translate-y-0.5 hover:border-fuchsia-400/30 hover:bg-white/[0.065]">
      <div className="absolute -right-10 -top-10 h-28 w-28 rounded-full bg-fuchsia-500/10 blur-3xl transition group-hover:bg-fuchsia-500/20" />
      <div className="relative flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-medium text-zinc-400">{label}</p>
          <p className="mt-3 text-3xl font-black tracking-tight text-white">{value}</p>
          <p className="mt-2 text-xs text-zinc-500">{detail}</p>
        </div>
        <div className="rounded-2xl border border-fuchsia-400/20 bg-fuchsia-500/10 p-3 text-fuchsia-300">
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </article>
  );
}

function Section({ title, subtitle, children }: {
  title: string; subtitle: string; children: React.ReactNode;
}) {
  return (
    <section className="rounded-3xl border border-white/10 bg-white/[0.035] p-5 shadow-2xl shadow-black/10 backdrop-blur-xl md:p-6">
      <div className="mb-5">
        <h2 className="text-lg font-bold text-white">{title}</h2>
        <p className="mt-1 text-sm text-zinc-500">{subtitle}</p>
      </div>
      {children}
    </section>
  );
}

function EmptyState({ icon: Icon, text }: { icon: typeof Activity; text: string }) {
  return (
    <div className="flex min-h-48 items-center justify-center rounded-2xl border border-dashed border-white/10 bg-black/20 p-8 text-center">
      <div>
        <Icon className="mx-auto h-7 w-7 text-zinc-600" />
        <p className="mt-3 text-sm text-zinc-500">{text}</p>
      </div>
    </div>
  );
}

export default function OwnerDashboardPage() {
  const [dashboard, setDashboard] = useState<DashboardResponse | null>(null);
  const [analytics, setAnalytics] = useState<AnalyticsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saleToast, setSaleToast] = useState<Sale | null>(null);
  const latestSaleIdRef = useRef<string | null>(null);
  const toastTimerRef = useRef<number | null>(null);

  const loadAllData = useCallback(async (silent = false) => {
    silent ? setRefreshing(true) : setLoading(true);

    try {
      const [dashboardResponse, analyticsResponse] = await Promise.all([
        fetch("/api/owner/dashboard", { cache: "no-store", credentials: "include" }),
        fetch("/api/owner/analytics", { cache: "no-store", credentials: "include" }),
      ]);

      const dashboardPayload = await dashboardResponse.json();
      const analyticsPayload = await analyticsResponse.json();

      if (!dashboardResponse.ok) {
        throw new Error(dashboardPayload.error || "Unable to load dashboard data.");
      }

      if (!analyticsResponse.ok) {
        throw new Error(analyticsPayload.error || "Unable to load analytics data.");
      }

      const nextDashboard = dashboardPayload as DashboardResponse;
      const newestSale = nextDashboard.latestSales[0] ?? null;

      if (newestSale) {
        if (
          latestSaleIdRef.current !== null &&
          newestSale.id !== latestSaleIdRef.current
        ) {
          setSaleToast(newestSale);

          if (toastTimerRef.current !== null) {
            window.clearTimeout(toastTimerRef.current);
          }

          toastTimerRef.current = window.setTimeout(() => {
            setSaleToast(null);
            toastTimerRef.current = null;
          }, 4_000);
        }

        latestSaleIdRef.current = newestSale.id;
      }

      setDashboard(nextDashboard);
      setAnalytics(analyticsPayload as AnalyticsResponse);
      setError(null);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Unable to load dashboard.");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void loadAllData();

    const interval = window.setInterval(() => {
      void loadAllData(true);
    }, 5_000);

    return () => {
      window.clearInterval(interval);
      if (toastTimerRef.current !== null) {
        window.clearTimeout(toastTimerRef.current);
      }
    };
  }, [loadAllData]);

  const paymentData = useMemo(() => {
    if (!analytics) return [];
    return [
      { name: "Cash", ...analytics.paymentMethods.cash },
      { name: "Card", ...analytics.paymentMethods.card },
      { name: "Wallet", ...analytics.paymentMethods.digitalWallet },
      { name: "Other", ...analytics.paymentMethods.other },
    ];
  }, [analytics]);

  const activityFeed = useMemo(() => {
    if (!dashboard) return [];

    const sales = dashboard.latestSales.map((sale) => ({
      id: `sale-${sale.id}`,
      type: "sale" as const,
      title: `${titleCase(sale.memberName)} made a purchase`,
      detail: `${titleCase(sale.paymentMethod)} payment`,
      value: formatMoney(sale.amount),
      timestamp: sale.createdAt,
    }));

    const redemptions = dashboard.recentRedemptions.map((redemption) => ({
      id: `redemption-${String(redemption.id)}`,
      type: "redemption" as const,
      title: redemption.reward_name || redemption.title || "Reward redeemed",
      detail: "Member reward redemption",
      value:
        redemption.points_spent != null
          ? `-${whole.format(Number(redemption.points_spent))} pts`
          : "",
      timestamp: String(
        redemption.created_at ??
          redemption.redeemed_at ??
          new Date(0).toISOString()
      ),
    }));

    return [...sales, ...redemptions]
      .sort(
        (a, b) =>
          new Date(b.timestamp).getTime() -
          new Date(a.timestamp).getTime()
      )
      .slice(0, 8);
  }, [dashboard]);
  const paymentTotal = paymentData.reduce((sum, item) => sum + item.revenue, 0);
  const goalProgress = dashboard
    ? Math.min(100, Math.max(0, (dashboard.summary.revenueToday / DAILY_REVENUE_GOAL) * 100))
    : 0;

  if (loading) {
    return (
      <main className="min-h-screen bg-[#07070a] text-white">
        <div className="flex min-h-screen items-center justify-center">
          <div className="text-center">
            <Loader2 className="mx-auto h-9 w-9 animate-spin text-fuchsia-400" />
            <p className="mt-4 text-sm text-zinc-400">Loading VIVID+ Command Center...</p>
          </div>
        </div>
      </main>
    );
  }

  if (error || !dashboard || !analytics) {
    return (
      <main className="min-h-screen bg-[#07070a] px-4 py-10 text-white">
        <div className="mx-auto max-w-xl rounded-3xl border border-red-400/20 bg-red-500/10 p-8 text-center">
          <Activity className="mx-auto h-9 w-9 text-red-300" />
          <h1 className="mt-4 text-xl font-bold">Dashboard unavailable</h1>
          <p className="mt-2 text-sm text-red-100/70">{error}</p>
          <button onClick={() => void loadAllData()} className="mt-6 rounded-2xl bg-white px-5 py-3 text-sm font-bold text-black">
            Try again
          </button>
        </div>
      </main>
    );
  }

  const { summary } = dashboard;
  const comparisonPositive = analytics.comparison.difference >= 0;
  return (
    <main className="min-h-screen overflow-hidden bg-[#07070a] text-white">
      {saleToast ? (
        <div className="fixed right-4 top-4 z-50 w-[calc(100%-2rem)] max-w-sm animate-[slideIn_.25s_ease-out] rounded-3xl border border-emerald-400/30 bg-[#111116]/95 p-4 shadow-2xl shadow-emerald-950/40 backdrop-blur-xl">
          <div className="flex items-start justify-between gap-3">
            <div className="flex items-start gap-3">
              <div className="rounded-2xl bg-emerald-500/15 p-2.5 text-emerald-300">
                <CircleDollarSign className="h-5 w-5" />
              </div>
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.18em] text-emerald-300">New sale</p>
                <p className="mt-1 font-bold text-white">{titleCase(saleToast.memberName)}</p>
                <p className="mt-1 text-sm text-zinc-400">
                  {formatMoney(saleToast.amount)} · +{whole.format(saleToast.pointsEarned)} points
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => setSaleToast(null)}
              className="rounded-xl p-1.5 text-zinc-500 transition hover:bg-white/5 hover:text-white"
              aria-label="Close sale notification"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        </div>
      ) : null}

      <div className="pointer-events-none fixed inset-0">
        <div className="absolute left-[-10%] top-[-10%] h-[420px] w-[420px] rounded-full bg-fuchsia-700/15 blur-[130px]" />
        <div className="absolute right-[-10%] top-[20%] h-[420px] w-[420px] rounded-full bg-violet-700/10 blur-[140px]" />
      </div>

      <div className="relative mx-auto max-w-7xl px-4 py-6 md:px-8 md:py-8">
        <header className="mb-7 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-fuchsia-400/20 bg-fuchsia-500/10 px-3 py-1 text-xs font-semibold text-fuchsia-200">
              <Sparkles className="h-3.5 w-3.5" /> Live owner intelligence
            </div>
            <h1 className="text-3xl font-black tracking-tight md:text-4xl">VIVID+ Command Center</h1>
            <p className="mt-2 max-w-2xl text-sm text-zinc-400 md:text-base">
              Live revenue, member activity, payments and lounge performance.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3">
              <p className="text-[11px] uppercase tracking-[0.18em] text-zinc-500">Business day</p>
              <p className="mt-1 text-sm font-semibold text-zinc-200">
                {dashboard.businessDay} · closes at {dashboard.businessDayCutoffHour}:00 AM
              </p>
            </div>
            <button
              type="button"
              onClick={() => void loadAllData(true)}
              disabled={refreshing}
              className="inline-flex items-center gap-2 rounded-2xl bg-white px-4 py-3 text-sm font-bold text-black disabled:opacity-60"
            >
              <RefreshCw className={`h-4 w-4 ${refreshing ? "animate-spin" : ""}`} />
              Refresh
            </button>
          </div>
        </header>

        <section className="mb-7 overflow-hidden rounded-3xl border border-white/10 bg-white/[0.035] p-5 shadow-2xl shadow-black/10 backdrop-blur-xl md:p-6">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="text-sm font-medium text-zinc-400">Today&apos;s revenue goal</p>
              <p className="mt-2 text-2xl font-black text-white">
                {formatMoney(summary.revenueToday)}
                <span className="ml-2 text-sm font-medium text-zinc-500">
                  / {formatMoney(DAILY_REVENUE_GOAL)}
                </span>
              </p>
            </div>
            <p className="text-sm font-bold text-fuchsia-300">{goalProgress.toFixed(0)}% complete</p>
          </div>
          <div className="mt-4 h-3 overflow-hidden rounded-full bg-black/40">
            <div
              className="h-full rounded-full bg-gradient-to-r from-fuchsia-600 via-violet-500 to-emerald-400 transition-[width] duration-700"
              style={{ width: `${goalProgress}%` }}
            />
          </div>
          <p className="mt-3 text-xs text-zinc-500">
            {summary.revenueToday >= DAILY_REVENUE_GOAL
              ? "Daily goal reached. Keep the momentum going."
              : `${formatMoney(Math.max(0, DAILY_REVENUE_GOAL - summary.revenueToday))} remaining to reach today&apos;s goal.`}
          </p>
        </section>

        <div className="mb-7 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard label="Revenue today" value={formatMoney(summary.revenueToday)}
            detail={`${summary.salesToday} completed sale${summary.salesToday === 1 ? "" : "s"}`}
            icon={CircleDollarSign} />
          <StatCard label="Average ticket" value={formatMoney(summary.averageTicket)}
            detail={`${summary.uniqueVisitorsToday} unique visitor${summary.uniqueVisitorsToday === 1 ? "" : "s"}`}
            icon={CreditCard} />
          <StatCard label="Active members" value={whole.format(summary.activeMembers)}
            detail={`${summary.newMembersToday} new this business day`} icon={Users} />
          <StatCard label="Points awarded" value={whole.format(summary.pointsAwardedToday)}
            detail={`${summary.rewardRedemptionsToday} reward redemption${summary.rewardRedemptionsToday === 1 ? "" : "s"}`}
            icon={Gift} />
        </div>

        <div className="grid gap-6 xl:grid-cols-[1.45fr_0.55fr]">
          <Section title="Hourly revenue" subtitle="Live Orlando business-day performance">
            <div className="mb-4 flex flex-wrap items-center gap-3">
              <div className="rounded-2xl border border-white/5 bg-black/20 px-4 py-3">
                <p className="text-xs text-zinc-500">Today</p>
                <p className="mt-1 text-xl font-black">{formatMoney(analytics.comparison.revenueToday)}</p>
              </div>
              <div className="rounded-2xl border border-white/5 bg-black/20 px-4 py-3">
                <p className="text-xs text-zinc-500">Yesterday</p>
                <p className="mt-1 text-xl font-black">{formatMoney(analytics.comparison.revenueYesterday)}</p>
              </div>
              <div className={`inline-flex items-center gap-2 rounded-2xl px-4 py-3 text-sm font-bold ${
                comparisonPositive ? "bg-emerald-500/10 text-emerald-300" : "bg-red-500/10 text-red-300"
              }`}>
                {comparisonPositive ? <TrendingUp className="h-4 w-4" /> : <TrendingDown className="h-4 w-4" />}
                {Math.abs(analytics.comparison.percentageChange).toFixed(1)}%
              </div>
            </div>

            <div className="mb-4 rounded-2xl border border-fuchsia-400/20 bg-fuchsia-500/[0.06] p-4">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-sm font-semibold text-white">Today's revenue goal</p>
                  <p className="mt-1 text-xs text-zinc-500">
                    {formatMoney(summary.revenueToday)} of {formatMoney(DAILY_REVENUE_GOAL)}
                  </p>
                </div>

                <span className="text-lg font-black text-fuchsia-300">
                  {Math.min((summary.revenueToday / DAILY_REVENUE_GOAL) * 100, 100).toFixed(1)}%
                </span>
              </div>

              <div className="mt-4 h-3 overflow-hidden rounded-full bg-black/40">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-fuchsia-600 to-violet-400 transition-all duration-700"
                  style={{
                    width: `${Math.min((summary.revenueToday / DAILY_REVENUE_GOAL) * 100, 100)}%`,
                  }}
                />
              </div>
            </div>

            <div className="h-72 rounded-2xl border border-white/5 bg-black/20 p-3">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={analytics.hourlySales} margin={{ top: 10, right: 8, left: -18, bottom: 0 }}>
                  <defs>
                    <linearGradient id="hourlyRevenue" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#d946ef" stopOpacity={0.5} />
                      <stop offset="95%" stopColor="#8b5cf6" stopOpacity={0.02} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid stroke="rgba(255,255,255,0.06)" vertical={false} />
                  <XAxis dataKey="label" tick={{ fill: "#71717a", fontSize: 10 }} axisLine={false} tickLine={false} interval={2} />
                  <YAxis tick={{ fill: "#71717a", fontSize: 10 }} axisLine={false} tickLine={false} tickFormatter={(v) => `$${Number(v)}`} />
                  <Tooltip contentStyle={{ background: "#18181b", border: "1px solid rgba(255,255,255,.1)", borderRadius: "14px" }}
                    formatter={(value) => [formatMoney(Number(value)), "Revenue"]} />
                  <Area type="monotone" dataKey="revenue" stroke="#e879f9" strokeWidth={3} fill="url(#hourlyRevenue)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </Section>

          <Section title="Payment methods" subtitle={`${formatMoney(paymentTotal)} collected today`}>
            <div className="h-52">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={paymentData} dataKey="revenue" nameKey="name" innerRadius={55} outerRadius={78} paddingAngle={4}>
                    {paymentData.map((entry, index) => (
                      <Cell key={entry.name} fill={PAYMENT_COLORS[index]} />
                    ))}
                  </Pie>
                  <Tooltip contentStyle={{ background: "#18181b", border: "1px solid rgba(255,255,255,.1)", borderRadius: "14px" }}
                    formatter={(value) => formatMoney(Number(value))} />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="space-y-2">
              {paymentData.map((item, index) => (
                <div key={item.name} className="flex items-center justify-between rounded-xl border border-white/5 bg-black/20 px-3 py-2">
                  <div className="flex items-center gap-2">
                    <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: PAYMENT_COLORS[index] }} />
                    <span className="text-sm text-zinc-400">{item.name}</span>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-bold">{formatMoney(item.revenue)}</p>
                    <p className="text-[10px] text-zinc-600">{item.sales} sale{item.sales === 1 ? "" : "s"}</p>
                  </div>
                </div>
              ))}
            </div>
          </Section>
        </div>

        <div className="mt-6 grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
          <Section title="7-day trend" subtitle="Revenue across recent business days">
            <div className="h-64 rounded-2xl border border-white/5 bg-black/20 p-3">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={analytics.dailyTrend} margin={{ top: 10, right: 8, left: -18, bottom: 0 }}>
                  <CartesianGrid stroke="rgba(255,255,255,0.06)" vertical={false} />
                  <XAxis dataKey="label" tick={{ fill: "#71717a", fontSize: 11 }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fill: "#71717a", fontSize: 10 }} axisLine={false} tickLine={false} tickFormatter={(v) => `$${Number(v)}`} />
                  <Tooltip contentStyle={{ background: "#18181b", border: "1px solid rgba(255,255,255,.1)", borderRadius: "14px" }}
                    formatter={(value) => [formatMoney(Number(value)), "Revenue"]} />
                  <Area type="monotone" dataKey="revenue" stroke="#a78bfa" strokeWidth={3} fill="rgba(139,92,246,.18)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </Section>

          <Section title="Top members" subtitle="Highest spending members in the last 8 days">
            {analytics.topMembers.length === 0 ? (
              <EmptyState icon={Trophy} text="Top members will appear after sales." />
            ) : (
              <div className="space-y-3">
                {analytics.topMembers.slice(0, 6).map((member) => (
                  <article key={member.memberId} className="flex items-center justify-between gap-3 rounded-2xl border border-white/5 bg-black/20 p-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-fuchsia-500/15 text-xs font-black text-fuchsia-200">
                        {member.rank}
                      </div>
                      <div className="min-w-0">
                        <p className="truncate text-sm font-semibold">{titleCase(member.memberName)}</p>
                        <p className="mt-1 text-xs text-zinc-500">
                          {member.visits} visit{member.visits === 1 ? "" : "s"} · {whole.format(member.pointsEarned)} points
                        </p>
                      </div>
                    </div>
                    <p className="shrink-0 text-sm font-black text-emerald-300">{formatMoney(member.revenue)}</p>
                  </article>
                ))}
              </div>
            )}
          </Section>
        </div>

        <div className="mt-6 grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
          <Section title="Latest sales" subtitle="Most recent member purchases">
            {dashboard.latestSales.length === 0 ? (
              <EmptyState icon={CircleDollarSign} text="No sales recorded during this business day." />
            ) : (
              <div className="space-y-3">
                {dashboard.latestSales.map((sale) => (
                  <article key={sale.id} className="flex flex-col gap-4 rounded-2xl border border-white/5 bg-black/20 p-4 sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex min-w-0 items-center gap-3">
                      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-fuchsia-500/15 text-sm font-black text-fuchsia-200">
                        {initials(sale.memberName)}
                      </div>
                      <div className="min-w-0">
                        <p className="truncate font-semibold">{titleCase(sale.memberName)}</p>
                        <p className="mt-1 text-xs text-zinc-500">
                          {formatTime(sale.createdAt)} · {titleCase(sale.paymentMethod)}
                          {sale.tier ? ` · ${titleCase(sale.tier)}` : ""}
                        </p>
                        {sale.note ? <p className="mt-1 truncate text-xs text-zinc-600">{sale.note}</p> : null}
                      </div>
                    </div>
                    <div className="sm:text-right">
                      <p className="font-black">{formatMoney(sale.amount)}</p>
                      <p className="mt-1 text-xs font-semibold text-emerald-300">+{whole.format(sale.pointsEarned)} points</p>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </Section>

          <Section title="Live activity" subtitle="Newest sales and reward activity">
            {activityFeed.length === 0 ? (
              <EmptyState icon={Activity} text="No activity recorded during this business day." />
            ) : (
              <div className="space-y-3">
                {activityFeed.map((item) => (
                  <article
                    key={item.id}
                    className="flex items-center justify-between gap-4 rounded-2xl border border-white/5 bg-black/20 p-4"
                  >
                    <div className="flex min-w-0 items-center gap-3">
                      <div
                        className={`rounded-xl p-2 ${
                          item.type === "sale"
                            ? "bg-fuchsia-500/10 text-fuchsia-300"
                            : "bg-emerald-500/10 text-emerald-300"
                        }`}
                      >
                        {item.type === "sale" ? (
                          <CircleDollarSign className="h-4 w-4" />
                        ) : (
                          <Gift className="h-4 w-4" />
                        )}
                      </div>

                      <div className="min-w-0">
                        <p className="truncate text-sm font-semibold">
                          {item.title}
                        </p>
                        <p className="mt-1 truncate text-xs text-zinc-500">
                          {item.detail} · {formatDateTime(item.timestamp)}
                        </p>
                      </div>
                    </div>

                    <span
                      className={`shrink-0 text-sm font-black ${
                        item.type === "sale"
                          ? "text-fuchsia-300"
                          : "text-emerald-300"
                      }`}
                    >
                      {item.value}
                    </span>
                  </article>
                ))}
              </div>
            )}
          </Section>
          <Section title="Business pulse" subtitle="Live operating snapshot">
            <BusinessPulse
              whole={whole}
              items={[
                { label: "Visits today", value: summary.visitsToday, icon: Activity },
                { label: "Total members", value: summary.totalMembers, icon: WalletCards },
                { label: "Active promotions", value: summary.activePromotions, icon: TicketCheck },
                { label: "Upcoming events", value: summary.upcomingEvents, icon: CalendarDays },
              ]}
            />
          </Section>
        </div>

        <div className="mt-6 grid gap-6 xl:grid-cols-2">
          <Section title="Active promotions" subtitle="Offers available to members">
            {dashboard.activePromotions.length === 0 ? (
              <EmptyState icon={TicketCheck} text="No active promotions." />
            ) : (
              <div className="space-y-3">
                {dashboard.activePromotions.slice(0, 6).map((promotion) => (
                  <article key={String(promotion.id ?? promotionName(promotion))} className="rounded-2xl border border-white/5 bg-black/20 p-4">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <p className="font-semibold">{promotionName(promotion)}</p>
                        <p className="mt-1 text-xs leading-5 text-zinc-500">
                          {promotion.description || promotion.terms || titleCase(promotion.promotion_type)}
                        </p>
                      </div>
                      <span className="shrink-0 rounded-xl bg-fuchsia-500/10 px-2.5 py-1 text-xs font-bold text-fuchsia-300">
                        {promotion.discount_price != null ? formatMoney(Number(promotion.discount_price)) : "LIVE"}
                      </span>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </Section>

          <Section title="Upcoming events" subtitle="Published events scheduled ahead">
            {dashboard.upcomingEvents.length === 0 ? (
              <EmptyState icon={CalendarDays} text="No upcoming events are published." />
            ) : (
              <div className="space-y-3">
                {dashboard.upcomingEvents.map((event) => (
                  <article key={String(event.id ?? eventName(event))} className="flex items-center gap-4 rounded-2xl border border-white/5 bg-black/20 p-4">
                    <div className="rounded-2xl bg-violet-500/10 p-3 text-violet-300"><CalendarDays className="h-5 w-5" /></div>
                    <div className="min-w-0">
                      <p className="truncate font-semibold">{eventName(event)}</p>
                      <p className="mt-1 text-xs text-zinc-500">{formatDateTime(eventDate(event))}</p>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </Section>
        </div>

        <div className="mt-6">
          <Section title="Recent redemptions" subtitle="Rewards redeemed during this business day">
            {dashboard.recentRedemptions.length === 0 ? (
              <EmptyState icon={Gift} text="No rewards redeemed yet." />
            ) : (
              <div className="grid gap-3 md:grid-cols-2">
                {dashboard.recentRedemptions.map((redemption) => (
                  <article key={String(redemption.id)} className="flex items-center justify-between gap-4 rounded-2xl border border-white/5 bg-black/20 p-4">
                    <div className="flex items-center gap-3">
                      <div className="rounded-xl bg-emerald-500/10 p-2 text-emerald-300"><Gift className="h-4 w-4" /></div>
                      <div>
                        <p className="text-sm font-semibold">{redemption.reward_name || redemption.title || "Reward redeemed"}</p>
                        <p className="mt-1 flex items-center gap-1 text-xs text-zinc-500">
                          <Clock3 className="h-3 w-3" />
                          {formatDateTime(redemption.created_at ?? redemption.redeemed_at)}
                        </p>
                      </div>
                    </div>
                    {redemption.points_spent != null ? (
                      <span className="text-sm font-bold text-emerald-300">-{whole.format(Number(redemption.points_spent))} pts</span>
                    ) : null}
                  </article>
                ))}
              </div>
            )}
          </Section>
        </div>

        <footer className="mt-7 flex flex-col gap-2 border-t border-white/5 pt-5 text-xs text-zinc-600 sm:flex-row sm:items-center sm:justify-between">
          <span>Auto-refreshes every 5 seconds · Orlando business time</span>
          <span>
            Last updated {new Intl.DateTimeFormat("en-US", {
              timeZone: "America/New_York", hour: "numeric", minute: "2-digit", second: "2-digit"
            }).format(new Date(dashboard.generatedAt))}
          </span>
        </footer>
      </div>
    </main>
  );
}
