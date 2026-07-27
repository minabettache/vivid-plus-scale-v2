"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Activity,
  CalendarDays,
  CircleDollarSign,
  Clock3,
  CreditCard,
  Gift,
  Loader2,
  RefreshCw,
  Sparkles,
  TicketCheck,
  TrendingUp,
  UserPlus,
  Users,
  WalletCards,
} from "lucide-react";

type Summary = {
  revenueToday: number;
  salesToday: number;
  visitsToday: number;
  uniqueVisitorsToday: number;
  averageTicket: number;
  pointsAwardedToday: number;
  totalMembers: number;
  activeMembers: number;
  newMembersToday: number;
  activePromotions: number;
  upcomingEvents: number;
  rewardRedemptionsToday: number;
};

type Sale = {
  id: string;
  memberId: string | null;
  memberName: string;
  amount: number;
  pointsEarned: number;
  paymentMethod: string;
  tier: string | null;
  note: string | null;
  createdAt: string | null;
};

type Promotion = {
  id?: string | number;
  name?: string | null;
  title?: string | null;
  description?: string | null;
  promotion_type?: string | null;
  discount_price?: number | string | null;
  terms?: string | null;
  start_time?: string | null;
  end_time?: string | null;
  day_of_week?: number | null;
};

type EventRow = {
  id?: string | number;
  title?: string | null;
  name?: string | null;
  description?: string | null;
  starts_at?: string | null;
  start_at?: string | null;
  event_at?: string | null;
  event_date?: string | null;
  date?: string | null;
};

type Redemption = {
  id?: string | number;
  reward_name?: string | null;
  title?: string | null;
  points_spent?: number | string | null;
  created_at?: string | null;
  redeemed_at?: string | null;
};

type DashboardResponse = {
  generatedAt: string;
  timezone: string;
  businessDayCutoffHour: number;
  businessDay: string;
  owner: {
    id: string;
    role: string;
  };
  summary: Summary;
  latestSales: Sale[];
  activePromotions: Promotion[];
  upcomingEvents: EventRow[];
  recentRedemptions: Redemption[];
};

const currency = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
});

const numberFormatter = new Intl.NumberFormat("en-US");

function formatMoney(value: number) {
  return currency.format(Number.isFinite(value) ? value : 0);
}

function titleCase(value: string | null | undefined) {
  if (!value) {
    return "Unknown";
  }

  return value
    .replaceAll("_", " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function formatTime(value: string | null) {
  if (!value) {
    return "Time unavailable";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "Time unavailable";
  }

  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

function formatDateTime(value: string | null | undefined) {
  if (!value) {
    return "Date to be announced";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

function getEventDate(event: EventRow) {
  return (
    event.starts_at ??
    event.start_at ??
    event.event_at ??
    event.event_date ??
    event.date ??
    null
  );
}

function promotionName(promotion: Promotion) {
  return promotion.name || promotion.title || "VIVID+ Promotion";
}

function eventName(event: EventRow) {
  return event.title || event.name || "VIVID+ Event";
}

function StatCard({
  label,
  value,
  detail,
  icon: Icon,
}: {
  label: string;
  value: string;
  detail: string;
  icon: typeof Activity;
}) {
  return (
    <article className="group relative overflow-hidden rounded-3xl border border-white/10 bg-white/[0.045] p-5 shadow-2xl shadow-black/10 backdrop-blur-xl transition hover:-translate-y-0.5 hover:border-fuchsia-400/30 hover:bg-white/[0.065]">
      <div className="absolute -right-10 -top-10 h-28 w-28 rounded-full bg-fuchsia-500/10 blur-3xl transition group-hover:bg-fuchsia-500/20" />

      <div className="relative flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-medium text-zinc-400">{label}</p>
          <p className="mt-3 text-3xl font-black tracking-tight text-white">
            {value}
          </p>
          <p className="mt-2 text-xs text-zinc-500">{detail}</p>
        </div>

        <div className="rounded-2xl border border-fuchsia-400/20 bg-fuchsia-500/10 p-3 text-fuchsia-300">
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </article>
  );
}

function Section({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
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

function SalesBars({ sales }: { sales: Sale[] }) {
  const chartSales = [...sales].reverse();
  const maxAmount = Math.max(
    ...chartSales.map((sale) => sale.amount),
    1,
  );

  if (chartSales.length === 0) {
    return (
      <div className="flex h-56 items-center justify-center rounded-2xl border border-dashed border-white/10 bg-black/20">
        <div className="text-center">
          <TrendingUp className="mx-auto h-7 w-7 text-zinc-600" />
          <p className="mt-3 text-sm text-zinc-500">
            Sales activity will appear here.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-56 items-end gap-2 rounded-2xl border border-white/5 bg-black/20 p-4">
      {chartSales.map((sale) => {
        const height = Math.max(
          12,
          Math.round((sale.amount / maxAmount) * 100),
        );

        return (
          <div
            key={sale.id}
            className="group flex min-w-0 flex-1 flex-col items-center justify-end gap-2"
            title={`${sale.memberName}: ${formatMoney(sale.amount)}`}
          >
            <div className="pointer-events-none opacity-0 transition group-hover:opacity-100">
              <span className="whitespace-nowrap rounded-lg bg-zinc-900 px-2 py-1 text-[10px] text-white shadow-xl">
                {formatMoney(sale.amount)}
              </span>
            </div>

            <div
              className="w-full rounded-t-xl bg-gradient-to-t from-fuchsia-600 to-violet-400 transition group-hover:brightness-125"
              style={{ height: `${height}%` }}
            />

            <span className="text-[10px] text-zinc-600">
              {formatTime(sale.createdAt)}
            </span>
          </div>
        );
      })}
    </div>
  );
}

export default function OwnerDashboardPage() {
  const [data, setData] = useState<DashboardResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadDashboard = useCallback(async (silent = false) => {
    if (silent) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }

    try {
      const response = await fetch("/api/owner/dashboard", {
        method: "GET",
        cache: "no-store",
        credentials: "include",
      });

      const payload = (await response.json()) as
        | DashboardResponse
        | { error?: string };

      if (!response.ok) {
        throw new Error(
          "error" in payload && payload.error
            ? payload.error
            : "Unable to load the owner dashboard.",
        );
      }

      setData(payload as DashboardResponse);
      setError(null);
    } catch (loadError) {
      setError(
        loadError instanceof Error
          ? loadError.message
          : "Unable to load the owner dashboard.",
      );
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void loadDashboard();

    const interval = window.setInterval(() => {
      void loadDashboard(true);
    }, 30_000);

    return () => {
      window.clearInterval(interval);
    };
  }, [loadDashboard]);

  const salesTotal = useMemo(
    () =>
      data?.latestSales.reduce(
        (total, sale) => total + sale.amount,
        0,
      ) ?? 0,
    [data],
  );

  if (loading) {
    return (
      <main className="min-h-screen bg-[#07070a] px-4 py-10 text-white md:px-8">
        <div className="mx-auto flex min-h-[65vh] max-w-7xl items-center justify-center">
          <div className="text-center">
            <Loader2 className="mx-auto h-9 w-9 animate-spin text-fuchsia-400" />
            <p className="mt-4 text-sm text-zinc-400">
              Loading VIVID+ Command Center...
            </p>
          </div>
        </div>
      </main>
    );
  }

  if (error || !data) {
    return (
      <main className="min-h-screen bg-[#07070a] px-4 py-10 text-white md:px-8">
        <div className="mx-auto max-w-xl rounded-3xl border border-red-400/20 bg-red-500/10 p-8 text-center">
          <Activity className="mx-auto h-9 w-9 text-red-300" />
          <h1 className="mt-4 text-xl font-bold">
            Dashboard unavailable
          </h1>
          <p className="mt-2 text-sm text-red-100/70">
            {error || "Unable to load dashboard data."}
          </p>
          <button
            type="button"
            onClick={() => void loadDashboard()}
            className="mt-6 rounded-2xl bg-white px-5 py-3 text-sm font-bold text-black transition hover:bg-zinc-200"
          >
            Try again
          </button>
        </div>
      </main>
    );
  }

  const { summary } = data;

  return (
    <main className="min-h-screen overflow-hidden bg-[#07070a] text-white">
      <div className="pointer-events-none fixed inset-0">
        <div className="absolute left-[-10%] top-[-10%] h-[420px] w-[420px] rounded-full bg-fuchsia-700/15 blur-[130px]" />
        <div className="absolute right-[-10%] top-[20%] h-[420px] w-[420px] rounded-full bg-violet-700/10 blur-[140px]" />
      </div>

      <div className="relative mx-auto max-w-7xl px-4 py-6 md:px-8 md:py-8">
        <header className="mb-7 flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-fuchsia-400/20 bg-fuchsia-500/10 px-3 py-1 text-xs font-semibold text-fuchsia-200">
              <Sparkles className="h-3.5 w-3.5" />
              Live owner intelligence
            </div>

            <h1 className="text-3xl font-black tracking-tight md:text-4xl">
              VIVID+ Command Center
            </h1>

            <p className="mt-2 max-w-2xl text-sm text-zinc-400 md:text-base">
              Live revenue, member activity, promotions and lounge
              performance in one place.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-3">
              <p className="text-[11px] uppercase tracking-[0.18em] text-zinc-500">
                Business day
              </p>
              <p className="mt-1 text-sm font-semibold text-zinc-200">
                {data.businessDay} · closes at{" "}
                {data.businessDayCutoffHour}:00 AM
              </p>
            </div>

            <button
              type="button"
              onClick={() => void loadDashboard(true)}
              disabled={refreshing}
              className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white px-4 py-3 text-sm font-bold text-black transition hover:bg-zinc-200 disabled:cursor-not-allowed disabled:opacity-60"
            >
              <RefreshCw
                className={`h-4 w-4 ${
                  refreshing ? "animate-spin" : ""
                }`}
              />
              Refresh
            </button>
          </div>
        </header>

        <div className="mb-7 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard
            label="Revenue today"
            value={formatMoney(summary.revenueToday)}
            detail={`${summary.salesToday} completed sale${
              summary.salesToday === 1 ? "" : "s"
            }`}
            icon={CircleDollarSign}
          />

          <StatCard
            label="Average ticket"
            value={formatMoney(summary.averageTicket)}
            detail={`${summary.uniqueVisitorsToday} unique visitor${
              summary.uniqueVisitorsToday === 1 ? "" : "s"
            }`}
            icon={CreditCard}
          />

          <StatCard
            label="Active members"
            value={numberFormatter.format(summary.activeMembers)}
            detail={`${summary.newMembersToday} new this business day`}
            icon={Users}
          />

          <StatCard
            label="Points awarded"
            value={numberFormatter.format(
              summary.pointsAwardedToday,
            )}
            detail={`${summary.rewardRedemptionsToday} reward redemption${
              summary.rewardRedemptionsToday === 1 ? "" : "s"
            }`}
            icon={Gift}
          />
        </div>

        <div className="grid gap-6 xl:grid-cols-[1.35fr_0.65fr]">
          <Section
            title="Sales activity"
            subtitle={`Latest recorded sales · ${formatMoney(
              salesTotal,
            )} shown`}
          >
            <SalesBars sales={data.latestSales} />
          </Section>

          <Section
            title="Business pulse"
            subtitle="Live operating snapshot"
          >
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-1">
              {[
                {
                  label: "Visits today",
                  value: summary.visitsToday,
                  icon: Activity,
                },
                {
                  label: "Total members",
                  value: summary.totalMembers,
                  icon: WalletCards,
                },
                {
                  label: "Active promotions",
                  value: summary.activePromotions,
                  icon: TicketCheck,
                },
                {
                  label: "Upcoming events",
                  value: summary.upcomingEvents,
                  icon: CalendarDays,
                },
              ].map((item) => (
                <div
                  key={item.label}
                  className="flex items-center justify-between rounded-2xl border border-white/5 bg-black/20 px-4 py-3"
                >
                  <div className="flex items-center gap-3">
                    <div className="rounded-xl bg-white/5 p-2 text-zinc-400">
                      <item.icon className="h-4 w-4" />
                    </div>
                    <span className="text-sm text-zinc-400">
                      {item.label}
                    </span>
                  </div>
                  <span className="text-lg font-black text-white">
                    {numberFormatter.format(item.value)}
                  </span>
                </div>
              ))}
            </div>
          </Section>
        </div>

        <div className="mt-6 grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
          <Section
            title="Latest sales"
            subtitle="Most recent member purchases"
          >
            {data.latestSales.length === 0 ? (
              <div className="rounded-2xl border border-dashed border-white/10 p-8 text-center text-sm text-zinc-500">
                No sales recorded during this business day.
              </div>
            ) : (
              <div className="space-y-3">
                {data.latestSales.map((sale) => (
                  <article
                    key={sale.id}
                    className="flex flex-col gap-4 rounded-2xl border border-white/5 bg-black/20 p-4 transition hover:border-white/10 hover:bg-white/[0.04] sm:flex-row sm:items-center sm:justify-between"
                  >
                    <div className="flex min-w-0 items-center gap-3">
                      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-fuchsia-500/20 to-violet-500/20 text-sm font-black text-fuchsia-200">
                        {sale.memberName
                          .split(" ")
                          .map((part) => part[0])
                          .join("")
                          .slice(0, 2)
                          .toUpperCase()}
                      </div>

                      <div className="min-w-0">
                        <p className="truncate font-semibold text-white">
                          {titleCase(sale.memberName)}
                        </p>
                        <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-zinc-500">
                          <span>{formatTime(sale.createdAt)}</span>
                          <span>•</span>
                          <span>{titleCase(sale.paymentMethod)}</span>
                          {sale.tier ? (
                            <>
                              <span>•</span>
                              <span>{titleCase(sale.tier)}</span>
                            </>
                          ) : null}
                        </div>
                        {sale.note ? (
                          <p className="mt-1 truncate text-xs text-zinc-600">
                            {sale.note}
                          </p>
                        ) : null}
                      </div>
                    </div>

                    <div className="flex items-center justify-between gap-5 sm:text-right">
                      <div>
                        <p className="font-black text-white">
                          {formatMoney(sale.amount)}
                        </p>
                        <p className="mt-1 text-xs font-semibold text-emerald-300">
                          +{numberFormatter.format(sale.pointsEarned)}{" "}
                          points
                        </p>
                      </div>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </Section>

          <Section
            title="Active promotions"
            subtitle="Offers currently available to members"
          >
            {data.activePromotions.length === 0 ? (
              <div className="rounded-2xl border border-dashed border-white/10 p-8 text-center text-sm text-zinc-500">
                No active promotions.
              </div>
            ) : (
              <div className="space-y-3">
                {data.activePromotions.slice(0, 6).map((promotion) => (
                  <article
                    key={String(promotion.id ?? promotionName(promotion))}
                    className="rounded-2xl border border-white/5 bg-black/20 p-4"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <p className="font-semibold text-white">
                          {promotionName(promotion)}
                        </p>
                        <p className="mt-1 line-clamp-2 text-xs leading-5 text-zinc-500">
                          {promotion.description ||
                            promotion.terms ||
                            titleCase(promotion.promotion_type)}
                        </p>
                      </div>

                      {promotion.discount_price != null ? (
                        <span className="shrink-0 rounded-xl bg-emerald-500/10 px-2.5 py-1 text-xs font-bold text-emerald-300">
                          {formatMoney(
                            Number(promotion.discount_price),
                          )}
                        </span>
                      ) : (
                        <span className="shrink-0 rounded-xl bg-fuchsia-500/10 px-2.5 py-1 text-xs font-bold text-fuchsia-300">
                          LIVE
                        </span>
                      )}
                    </div>
                  </article>
                ))}
              </div>
            )}
          </Section>
        </div>

        <div className="mt-6 grid gap-6 lg:grid-cols-2">
          <Section
            title="Upcoming events"
            subtitle="Published events scheduled ahead"
          >
            {data.upcomingEvents.length === 0 ? (
              <div className="rounded-2xl border border-dashed border-white/10 p-8 text-center">
                <CalendarDays className="mx-auto h-7 w-7 text-zinc-600" />
                <p className="mt-3 text-sm text-zinc-500">
                  No upcoming events are published.
                </p>
              </div>
            ) : (
              <div className="space-y-3">
                {data.upcomingEvents.map((event) => (
                  <article
                    key={String(event.id ?? eventName(event))}
                    className="flex items-center gap-4 rounded-2xl border border-white/5 bg-black/20 p-4"
                  >
                    <div className="rounded-2xl bg-violet-500/10 p-3 text-violet-300">
                      <CalendarDays className="h-5 w-5" />
                    </div>
                    <div className="min-w-0">
                      <p className="truncate font-semibold text-white">
                        {eventName(event)}
                      </p>
                      <p className="mt-1 text-xs text-zinc-500">
                        {formatDateTime(getEventDate(event))}
                      </p>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </Section>

          <Section
            title="Recent redemptions"
            subtitle="Rewards redeemed during this business day"
          >
            {data.recentRedemptions.length === 0 ? (
              <div className="rounded-2xl border border-dashed border-white/10 p-8 text-center">
                <Gift className="mx-auto h-7 w-7 text-zinc-600" />
                <p className="mt-3 text-sm text-zinc-500">
                  No rewards redeemed yet.
                </p>
              </div>
            ) : (
              <div className="space-y-3">
                {data.recentRedemptions.map((redemption) => (
                  <article
                    key={String(redemption.id)}
                    className="flex items-center justify-between gap-4 rounded-2xl border border-white/5 bg-black/20 p-4"
                  >
                    <div className="flex items-center gap-3">
                      <div className="rounded-xl bg-emerald-500/10 p-2 text-emerald-300">
                        <Gift className="h-4 w-4" />
                      </div>
                      <div>
                        <p className="text-sm font-semibold text-white">
                          {redemption.reward_name ||
                            redemption.title ||
                            "Reward redeemed"}
                        </p>
                        <p className="mt-1 flex items-center gap-1 text-xs text-zinc-500">
                          <Clock3 className="h-3 w-3" />
                          {formatDateTime(
                            redemption.created_at ??
                              redemption.redeemed_at,
                          )}
                        </p>
                      </div>
                    </div>

                    {redemption.points_spent != null ? (
                      <span className="text-sm font-bold text-emerald-300">
                        -
                        {numberFormatter.format(
                          Number(redemption.points_spent),
                        )}{" "}
                        pts
                      </span>
                    ) : null}
                  </article>
                ))}
              </div>
            )}
          </Section>
        </div>

        <footer className="mt-7 flex flex-col gap-2 border-t border-white/5 pt-5 text-xs text-zinc-600 sm:flex-row sm:items-center sm:justify-between">
          <span>
            Auto-refreshes every 30 seconds · Orlando business time
          </span>
          <span>
            Last updated{" "}
            {new Intl.DateTimeFormat("en-US", {
              timeZone: "America/New_York",
              hour: "numeric",
              minute: "2-digit",
              second: "2-digit",
            }).format(new Date(data.generatedAt))}
          </span>
        </footer>
      </div>
    </main>
  );
}