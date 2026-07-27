import { redirect } from 'next/navigation';
import {
  Activity,
  Award,
  CalendarDays,
  CircleDollarSign,
  Clock3,
  Crown,
  TrendingUp,
  UserPlus,
  Users,
} from 'lucide-react';
import { OwnerNavigation } from '@/components/OwnerNavigation';
import { requireOwner } from '@/lib/auth/require-owner';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type MemberRow = {
  id: number;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  membership_level: string | null;
  points: number | null;
  lifetime_points: number | null;
  total_visits: number | null;
  total_spent: number | string | null;
  created_at: string;
  last_visit_at: string | null;
};

type TransactionRow = {
  id: number;
  member_id: number;
  points_delta: number;
  balance_after: number;
  transaction_type: string;
  reason: string;
  created_at: string;
  members:
    | {
        full_name: string | null;
      }
    | {
        full_name: string | null;
      }[]
    | null;
};

type DailyActivity = {
  label: string;
  date: string;
  visits: number;
  points: number;
};

function startOfDay(date: Date) {
  const result = new Date(date);
  result.setHours(0, 0, 0, 0);
  return result;
}

function startOfMonth(date: Date) {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    1,
  );
}

function addDays(date: Date, amount: number) {
  const result = new Date(date);
  result.setDate(result.getDate() + amount);
  return result;
}

function formatDateTime(value: string) {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return 'Unknown time';
  }

  return new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/New_York',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

function formatMoney(value: number | string | null) {
  const numericValue = Number(value ?? 0);

  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(
    Number.isFinite(numericValue) ? numericValue : 0,
  );
}

function getMemberName(transaction: TransactionRow) {
  if (Array.isArray(transaction.members)) {
    return (
      transaction.members[0]?.full_name ||
      'VIVID+ Member'
    );
  }

  return (
    transaction.members?.full_name ||
    'VIVID+ Member'
  );
}

function buildSevenDayActivity(
  transactions: TransactionRow[],
  today: Date,
): DailyActivity[] {
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = addDays(startOfDay(today), index - 6);

    return {
      label: new Intl.DateTimeFormat('en-US', {
        weekday: 'short',
      }).format(date),
      date: date.toISOString().slice(0, 10),
      visits: 0,
      points: 0,
    };
  });

  const activityMap = new Map(
    days.map((day) => [day.date, day]),
  );

  for (const transaction of transactions) {
    const transactionDate = new Date(
      transaction.created_at,
    );

    if (Number.isNaN(transactionDate.getTime())) {
      continue;
    }

    const key = transactionDate
      .toISOString()
      .slice(0, 10);

    const day = activityMap.get(key);

    if (!day) {
      continue;
    }

    if (
      transaction.transaction_type === 'award' ||
      transaction.transaction_type === 'welcome'
    ) {
      day.visits +=
        transaction.transaction_type === 'award'
          ? 1
          : 0;

      day.points += Math.max(
        0,
        Number(transaction.points_delta ?? 0),
      );
    }
  }

  return days;
}

async function loadAnalytics() {
  const supabase = await createClient();

  const now = new Date();
  const todayStart = startOfDay(now);
  const monthStart = startOfMonth(now);
  const sevenDaysAgo = addDays(todayStart, -6);

  const [
    activeMembersResult,
    newMembersResult,
    visitsTodayResult,
    monthTransactionsResult,
    sevenDayTransactionsResult,
    topMembersResult,
    recentTransactionsResult,
  ] = await Promise.all([
    supabase
      .from('members')
      .select('*', {
        count: 'exact',
        head: true,
      })
      .eq('is_active', true),

    supabase
      .from('members')
      .select('*', {
        count: 'exact',
        head: true,
      })
      .gte('created_at', monthStart.toISOString()),

    supabase
      .from('points_transactions')
      .select('*', {
        count: 'exact',
        head: true,
      })
      .eq('transaction_type', 'award')
      .gte('created_at', todayStart.toISOString()),

    supabase
      .from('points_transactions')
      .select(`
        id,
        member_id,
        points_delta,
        balance_after,
        transaction_type,
        reason,
        created_at,
        members (
          full_name
        )
      `)
      .gte('created_at', monthStart.toISOString())
      .order('created_at', {
        ascending: false,
      })
      .limit(5000),

    supabase
      .from('points_transactions')
      .select(`
        id,
        member_id,
        points_delta,
        balance_after,
        transaction_type,
        reason,
        created_at,
        members (
          full_name
        )
      `)
      .gte('created_at', sevenDaysAgo.toISOString())
      .order('created_at', {
        ascending: true,
      })
      .limit(5000),

    supabase
      .from('members')
      .select(`
        id,
        full_name,
        email,
        phone,
        membership_level,
        points,
        lifetime_points,
        total_visits,
        total_spent,
        created_at,
        last_visit_at
      `)
      .eq('is_active', true)
      .order('lifetime_points', {
        ascending: false,
      })
      .limit(10),

    supabase
      .from('points_transactions')
      .select(`
        id,
        member_id,
        points_delta,
        balance_after,
        transaction_type,
        reason,
        created_at,
        members (
          full_name
        )
      `)
      .order('created_at', {
        ascending: false,
      })
      .limit(12),
  ]);

  const errors = [
    activeMembersResult.error,
    newMembersResult.error,
    visitsTodayResult.error,
    monthTransactionsResult.error,
    sevenDayTransactionsResult.error,
    topMembersResult.error,
    recentTransactionsResult.error,
  ].filter(Boolean);

  if (errors.length > 0) {
    console.error(
      'Analytics query errors:',
      errors,
    );
  }

  const monthTransactions =
    (monthTransactionsResult.data ??
      []) as TransactionRow[];

  const sevenDayTransactions =
    (sevenDayTransactionsResult.data ??
      []) as TransactionRow[];

  const topMembers =
    (topMembersResult.data ??
      []) as MemberRow[];

  const recentTransactions =
    (recentTransactionsResult.data ??
      []) as TransactionRow[];

  const pointsAwardedThisMonth =
    monthTransactions.reduce(
      (total, transaction) => {
        if (
          transaction.transaction_type !== 'award' &&
          transaction.transaction_type !== 'welcome'
        ) {
          return total;
        }

        return (
          total +
          Math.max(
            0,
            Number(transaction.points_delta ?? 0),
          )
        );
      },
      0,
    );

  const pointsRedeemedThisMonth =
    monthTransactions.reduce(
      (total, transaction) => {
        if (
          transaction.transaction_type !== 'redeem'
        ) {
          return total;
        }

        return (
          total +
          Math.abs(
            Number(transaction.points_delta ?? 0),
          )
        );
      },
      0,
    );

  const sevenDayActivity =
    buildSevenDayActivity(
      sevenDayTransactions,
      now,
    );

  return {
    activeMembers:
      activeMembersResult.count ?? 0,
    newMembers:
      newMembersResult.count ?? 0,
    visitsToday:
      visitsTodayResult.count ?? 0,
    pointsAwardedThisMonth,
    pointsRedeemedThisMonth,
    monthTransactions:
      monthTransactions.length,
    sevenDayActivity,
    topMembers,
    recentTransactions,
    hasErrors: errors.length > 0,
  };
}

export default async function OwnerAnalyticsPage() {
  let owner;

  try {
    const result = await requireOwner();
    owner = result.staff;
  } catch {
    redirect('/staff/login');
  }

  const analytics = await loadAnalytics();

  const totalSevenDayVisits =
    analytics.sevenDayActivity.reduce(
      (total, day) => total + day.visits,
      0,
    );

  const totalSevenDayPoints =
    analytics.sevenDayActivity.reduce(
      (total, day) => total + day.points,
      0,
    );

  const maxDailyActivity = Math.max(
    1,
    ...analytics.sevenDayActivity.map(
      (day) => day.visits,
    ),
  );

  const metrics = [
    {
      label: 'Active members',
      value:
        analytics.activeMembers.toLocaleString(),
      note: 'Current active VIVID+ members',
      icon: Users,
    },
    {
      label: 'New this month',
      value:
        analytics.newMembers.toLocaleString(),
      note: 'Members who recently joined',
      icon: UserPlus,
    },
    {
      label: 'Visits today',
      value:
        analytics.visitsToday.toLocaleString(),
      note: 'Scanner point transactions today',
      icon: Activity,
    },
    {
      label: 'Points awarded',
      value:
        analytics.pointsAwardedThisMonth.toLocaleString(),
      note: 'Total awarded this month',
      icon: Award,
    },
    {
      label: 'Points redeemed',
      value:
        analytics.pointsRedeemedThisMonth.toLocaleString(),
      note: 'Total redeemed this month',
      icon: Crown,
    },
    {
      label: 'Monthly activity',
      value:
        analytics.monthTransactions.toLocaleString(),
      note: 'Point ledger entries this month',
      icon: TrendingUp,
    },
  ];

  return (
    <main
      style={{
        minHeight: '100vh',
        padding: 24,
        background: '#090909',
        color: '#ffffff',
      }}
    >
      <section
        style={{
          maxWidth: 1250,
          margin: '0 auto',
          display: 'grid',
          gridTemplateColumns:
            'minmax(220px, 260px) minmax(0, 1fr)',
          gap: 28,
        }}
      >
        <OwnerNavigation active="analytics" />

        <div>
          <header>
            <p
              style={{
                margin: 0,
                color: '#f5a623',
                fontSize: 13,
                fontWeight: 900,
                letterSpacing: '0.09em',
              }}
            >
              VIVID+ BUSINESS INTELLIGENCE
            </p>

            <h1
              style={{
                margin: '14px 0 0',
                fontSize:
                  'clamp(2.5rem, 7vw, 5.5rem)',
                lineHeight: 0.95,
              }}
            >
              Analytics
            </h1>

            <p
              style={{
                marginTop: 18,
                color: '#aaaaaa',
                fontSize: 17,
                lineHeight: 1.6,
              }}
            >
              Welcome, {owner.full_name}. Review member
              growth, visits, points and customer
              activity.
            </p>
          </header>

          {analytics.hasErrors && (
            <div
              style={{
                marginTop: 24,
                padding: 15,
                borderRadius: 14,
                border: '1px solid #67491c',
                background: '#21190d',
                color: '#f5c46d',
              }}
            >
              Some analytics could not be loaded. The
              available information is shown below.
            </div>
          )}

          <section
            style={{
              display: 'grid',
              gridTemplateColumns:
                'repeat(auto-fit, minmax(210px, 1fr))',
              gap: 16,
              marginTop: 34,
            }}
          >
            {metrics.map(
              ({
                label,
                value,
                note,
                icon: Icon,
              }) => (
                <article
                  key={label}
                  style={{
                    padding: 22,
                    borderRadius: 20,
                    border: '1px solid #303030',
                    background:
                      'linear-gradient(145deg, #181818 0%, #111111 100%)',
                  }}
                >
                  <div
                    style={{
                      display: 'flex',
                      justifyContent:
                        'space-between',
                      alignItems: 'center',
                      gap: 14,
                    }}
                  >
                    <span
                      style={{
                        color: '#b8b8b8',
                        fontWeight: 800,
                      }}
                    >
                      {label}
                    </span>

                    <div
                      style={{
                        width: 42,
                        height: 42,
                        display: 'grid',
                        placeItems: 'center',
                        borderRadius: 13,
                        background:
                          'rgba(245, 166, 35, 0.14)',
                        color: '#f5a623',
                      }}
                    >
                      <Icon size={20} />
                    </div>
                  </div>

                  <strong
                    style={{
                      display: 'block',
                      marginTop: 24,
                      fontSize: 38,
                    }}
                  >
                    {value}
                  </strong>

                  <p
                    style={{
                      margin: '8px 0 0',
                      color: '#8d8d8d',
                    }}
                  >
                    {note}
                  </p>
                </article>
              ),
            )}
          </section>

          <section
            style={{
              marginTop: 28,
              padding: 24,
              borderRadius: 22,
              border: '1px solid #303030',
              background: '#131313',
            }}
          >
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'flex-start',
                gap: 18,
                flexWrap: 'wrap',
              }}
            >
              <div>
                <p
                  style={{
                    margin: 0,
                    color: '#f5a623',
                    fontSize: 13,
                    fontWeight: 900,
                    letterSpacing: '0.08em',
                  }}
                >
                  LAST 7 DAYS
                </p>

                <h2
                  style={{
                    margin: '10px 0 0',
                  }}
                >
                  Member activity
                </h2>
              </div>

              <div
                style={{
                  display: 'flex',
                  gap: 12,
                  flexWrap: 'wrap',
                }}
              >
                <SmallSummary
                  label="Visits"
                  value={totalSevenDayVisits}
                />

                <SmallSummary
                  label="Points"
                  value={totalSevenDayPoints}
                />
              </div>
            </div>

            <div
              style={{
                display: 'grid',
                gridTemplateColumns:
                  'repeat(7, minmax(56px, 1fr))',
                gap: 12,
                alignItems: 'end',
                minHeight: 270,
                marginTop: 30,
                overflowX: 'auto',
              }}
            >
              {analytics.sevenDayActivity.map(
                (day) => {
                  const height = Math.max(
                    12,
                    Math.round(
                      (day.visits /
                        maxDailyActivity) *
                        180,
                    ),
                  );

                  return (
                    <div
                      key={day.date}
                      style={{
                        display: 'grid',
                        gap: 10,
                        justifyItems: 'center',
                        minWidth: 58,
                      }}
                    >
                      <strong
                        style={{
                          color: '#f5a623',
                        }}
                      >
                        {day.visits}
                      </strong>

                      <div
                        title={`${day.visits} visits and ${day.points} points`}
                        style={{
                          width: '100%',
                          maxWidth: 54,
                          height,
                          minHeight: 12,
                          borderRadius:
                            '10px 10px 4px 4px',
                          background:
                            'linear-gradient(180deg, #f5a623 0%, #785012 100%)',
                        }}
                      />

                      <span
                        style={{
                          color: '#999999',
                          fontSize: 13,
                          fontWeight: 800,
                        }}
                      >
                        {day.label}
                      </span>
                    </div>
                  );
                },
              )}
            </div>
          </section>

          <section
            style={{
              display: 'grid',
              gridTemplateColumns:
                'repeat(auto-fit, minmax(320px, 1fr))',
              gap: 20,
              marginTop: 28,
            }}
          >
            <article
              style={{
                padding: 24,
                borderRadius: 22,
                border: '1px solid #303030',
                background: '#131313',
              }}
            >
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                }}
              >
                <Crown
                  size={22}
                  color="#f5a623"
                />

                <h2 style={{ margin: 0 }}>
                  Top members
                </h2>
              </div>

              <div
                style={{
                  display: 'grid',
                  gap: 12,
                  marginTop: 22,
                }}
              >
                {analytics.topMembers.length ===
                0 ? (
                  <EmptyState text="No member activity yet." />
                ) : (
                  analytics.topMembers.map(
                    (member, index) => (
                      <div
                        key={member.id}
                        style={{
                          display: 'grid',
                          gridTemplateColumns:
                            '38px minmax(0, 1fr) auto',
                          alignItems: 'center',
                          gap: 12,
                          padding: 14,
                          borderRadius: 14,
                          background: '#1b1b1b',
                        }}
                      >
                        <div
                          style={{
                            width: 38,
                            height: 38,
                            display: 'grid',
                            placeItems: 'center',
                            borderRadius: 12,
                            background:
                              index === 0
                                ? '#f5a623'
                                : '#292929',
                            color:
                              index === 0
                                ? '#111111'
                                : '#ffffff',
                            fontWeight: 900,
                          }}
                        >
                          {index + 1}
                        </div>

                        <div
                          style={{
                            minWidth: 0,
                          }}
                        >
                          <strong>
                            {member.full_name ||
                              'VIVID+ Member'}
                          </strong>

                          <p
                            style={{
                              margin: '5px 0 0',
                              color: '#909090',
                              fontSize: 13,
                            }}
                          >
                            {Number(
                              member.total_visits ??
                                0,
                            ).toLocaleString()}{' '}
                            visits ·{' '}
                            {formatMoney(
                              member.total_spent,
                            )}
                          </p>
                        </div>

                        <strong
                          style={{
                            color: '#f5a623',
                          }}
                        >
                          {Number(
                            member.lifetime_points ??
                              0,
                          ).toLocaleString()}
                        </strong>
                      </div>
                    ),
                  )
                )}
              </div>
            </article>

            <article
              style={{
                padding: 24,
                borderRadius: 22,
                border: '1px solid #303030',
                background: '#131313',
              }}
            >
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                }}
              >
                <Clock3
                  size={22}
                  color="#f5a623"
                />

                <h2 style={{ margin: 0 }}>
                  Recent activity
                </h2>
              </div>

              <div
                style={{
                  display: 'grid',
                  gap: 12,
                  marginTop: 22,
                }}
              >
                {analytics.recentTransactions
                  .length === 0 ? (
                  <EmptyState text="No transactions yet." />
                ) : (
                  analytics.recentTransactions.map(
                    (transaction) => (
                      <div
                        key={transaction.id}
                        style={{
                          display: 'flex',
                          justifyContent:
                            'space-between',
                          alignItems: 'center',
                          gap: 14,
                          padding: 14,
                          borderRadius: 14,
                          background: '#1b1b1b',
                        }}
                      >
                        <div>
                          <strong>
                            {getMemberName(
                              transaction,
                            )}
                          </strong>

                          <p
                            style={{
                              margin: '5px 0 0',
                              color: '#919191',
                              fontSize: 13,
                            }}
                          >
                            {transaction.reason} ·{' '}
                            {formatDateTime(
                              transaction.created_at,
                            )}
                          </p>
                        </div>

                        <strong
                          style={{
                            color:
                              transaction.points_delta >=
                              0
                                ? '#76d69b'
                                : '#ef7c7c',
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {transaction.points_delta >= 0
                            ? '+'
                            : ''}
                          {Number(
                            transaction.points_delta,
                          ).toLocaleString()}
                        </strong>
                      </div>
                    ),
                  )
                )}
              </div>
            </article>
          </section>

          <section
            style={{
              display: 'grid',
              gridTemplateColumns:
                'repeat(auto-fit, minmax(220px, 1fr))',
              gap: 16,
              marginTop: 28,
            }}
          >
            <InsightCard
              icon={CalendarDays}
              title="Customer visits"
              description={`${totalSevenDayVisits.toLocaleString()} recorded visits during the last seven days.`}
            />

            <InsightCard
              icon={CircleDollarSign}
              title="Customer value"
              description="Total spend will increase as purchase amounts are connected to scanner transactions."
            />

            <InsightCard
              icon={TrendingUp}
              title="Growth tracking"
              description={`${analytics.newMembers.toLocaleString()} new members have joined during the current month.`}
            />
          </section>
        </div>
      </section>
    </main>
  );
}

function SmallSummary({
  label,
  value,
}: {
  label: string;
  value: number;
}) {
  return (
    <div
      style={{
        minWidth: 110,
        padding: '12px 15px',
        borderRadius: 14,
        background: '#1f1f1f',
      }}
    >
      <span
        style={{
          display: 'block',
          color: '#8f8f8f',
          fontSize: 12,
          fontWeight: 800,
          textTransform: 'uppercase',
        }}
      >
        {label}
      </span>

      <strong
        style={{
          display: 'block',
          marginTop: 5,
          fontSize: 21,
        }}
      >
        {value.toLocaleString()}
      </strong>
    </div>
  );
}

function InsightCard({
  icon: Icon,
  title,
  description,
}: {
  icon: typeof CalendarDays;
  title: string;
  description: string;
}) {
  return (
    <article
      style={{
        padding: 21,
        borderRadius: 20,
        border: '1px solid #303030',
        background: '#141414',
      }}
    >
      <div
        style={{
          width: 43,
          height: 43,
          display: 'grid',
          placeItems: 'center',
          borderRadius: 13,
          background:
            'rgba(245, 166, 35, 0.14)',
          color: '#f5a623',
        }}
      >
        <Icon size={21} />
      </div>

      <h3
        style={{
          margin: '20px 0 0',
        }}
      >
        {title}
      </h3>

      <p
        style={{
          margin: '9px 0 0',
          color: '#969696',
          lineHeight: 1.55,
        }}
      >
        {description}
      </p>
    </article>
  );
}

function EmptyState({
  text,
}: {
  text: string;
}) {
  return (
    <div
      style={{
        padding: 20,
        borderRadius: 14,
        border: '1px dashed #383838',
        color: '#888888',
        textAlign: 'center',
      }}
    >
      {text}
    </div>
  );
}
