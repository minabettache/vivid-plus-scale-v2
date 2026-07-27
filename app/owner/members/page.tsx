import Link from 'next/link';
import { redirect } from 'next/navigation';
import {
  Activity,
  ArrowRight,
  BadgeCheck,
  CalendarDays,
  CreditCard,
  Mail,
  Phone,
  QrCode,
  ScanLine,
  Search,
  ShieldCheck,
  Sparkles,
  UserRound,
  Users,
  WalletCards,
} from 'lucide-react';

import { OwnerNavigation } from '@/components/OwnerNavigation';
import { requireOwner } from '@/lib/auth/require-owner';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{
  search?: string;
  member?: string;
}>;

type MemberRow = {
  id: string;
  full_name: string | null;
  phone: string | null;
  email: string | null;
  membership_level: string | null;
  points: number | null;
  lifetime_points: number | null;
  total_visits: number | null;
  total_spent: number | null;
  birthday: string | null;
  qr_code: string | null;
  is_active: boolean | null;
  created_at?: string | null;
  last_visit_at: string | null;
};

type TransactionRow = {
  id?: string;
  points?: number | null;
  amount?: number | null;
  transaction_type?: string | null;
  type?: string | null;
  description?: string | null;
  reason?: string | null;
  created_at?: string | null;
};

function formatNumber(value: number | null | undefined) {
  return new Intl.NumberFormat('en-US').format(value ?? 0);
}

function formatCurrency(value: number | null | undefined) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(value ?? 0);
}

function formatDate(value: string | null | undefined) {
  if (!value) {
    return 'Not available';
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
}

function formatDateTime(value: string | null | undefined) {
  if (!value) {
    return 'Not available';
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

function getInitials(name: string | null) {
  if (!name) {
    return 'M';
  }

  const initials = name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('');

  return initials || 'M';
}

function getTransactionPoints(transaction: TransactionRow) {
  if (typeof transaction.points === 'number') {
    return transaction.points;
  }

  if (typeof transaction.amount === 'number') {
    return transaction.amount;
  }

  return 0;
}

function getTransactionTitle(transaction: TransactionRow) {
  return (
    transaction.description ||
    transaction.reason ||
    transaction.transaction_type ||
    transaction.type ||
    'Points activity'
  );
}

function getMembershipLabel(level: string | null) {
  if (!level) {
    return 'Member';
  }

  return level
    .replaceAll('_', ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

export default async function OwnerMembersPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  try {
    await requireOwner();
  } catch {
    redirect('/staff/login');
  }

  const params = await searchParams;
  const search = params.search?.trim() ?? '';
  const requestedMemberId = params.member?.trim() ?? '';

  const supabase = await createClient();

  let membersQuery = supabase
    .from('members')
    .select(
      `
        id,
        full_name,
        phone,
        email,
        membership_level,
        points,
        lifetime_points,
        total_visits,
        total_spent,
        birthday,
        qr_code,
        is_active,
        created_at,
        last_visit_at
      `,
    )
    .order('created_at', {
      ascending: false,
    })
    .limit(100);

  if (search) {
    const safeSearch = search.replace(/[,%()]/g, ' ').trim();

    if (safeSearch) {
      membersQuery = membersQuery.or(
        [
          `full_name.ilike.%${safeSearch}%`,
          `phone.ilike.%${safeSearch}%`,
          `email.ilike.%${safeSearch}%`,
          `qr_code.ilike.%${safeSearch}%`,
        ].join(','),
      );
    }
  }

  const [
    membersResponse,
    activeCountResponse,
    totalCountResponse,
    totalPointsResponse,
  ] = await Promise.all([
    membersQuery,
    supabase
      .from('members')
      .select('*', {
        count: 'exact',
        head: true,
      })
      .eq('is_active', true),
    supabase.from('members').select('*', {
      count: 'exact',
      head: true,
    }),
    supabase
      .from('members')
      .select('points, lifetime_points, total_visits, total_spent'),
  ]);

  const members = (membersResponse.data ?? []) as MemberRow[];

  const selectedMemberId =
    requestedMemberId || members.at(0)?.id || '';

  let selectedMember =
    members.find((member) => member.id === selectedMemberId) ?? null;

  if (!selectedMember && selectedMemberId) {
    const selectedMemberResponse = await supabase
      .from('members')
      .select(
        `
          id,
          full_name,
          phone,
          email,
          membership_level,
          points,
          lifetime_points,
          total_visits,
          total_spent,
          birthday,
          qr_code,
          is_active,
          created_at,
          last_visit_at
        `,
      )
      .eq('id', selectedMemberId)
      .maybeSingle();

    selectedMember =
      (selectedMemberResponse.data as MemberRow | null) ?? null;
  }

  let transactions: TransactionRow[] = [];

  if (selectedMember?.id) {
    const transactionResponse = await supabase
      .from('points_transactions')
      .select('*')
      .eq('member_id', selectedMember.id)
      .order('created_at', {
        ascending: false,
      })
      .limit(15);

    transactions =
      (transactionResponse.data as TransactionRow[] | null) ?? [];
  }

  const aggregateRows =
    (totalPointsResponse.data as
      | Array<{
          points: number | null;
          lifetime_points: number | null;
          total_visits: number | null;
          total_spent: number | null;
        }>
      | null) ?? [];

  const totalCurrentPoints = aggregateRows.reduce(
    (sum, member) => sum + (member.points ?? 0),
    0,
  );

  const totalLifetimePoints = aggregateRows.reduce(
    (sum, member) => sum + (member.lifetime_points ?? 0),
    0,
  );

  const totalVisits = aggregateRows.reduce(
    (sum, member) => sum + (member.total_visits ?? 0),
    0,
  );

  const totalSpent = aggregateRows.reduce(
    (sum, member) => sum + (member.total_spent ?? 0),
    0,
  );

  const totalMembers = totalCountResponse.count ?? 0;
  const activeMembers = activeCountResponse.count ?? 0;

  return (
    <main
      style={{
        minHeight: '100vh',
        background:
          'radial-gradient(circle at top, #262016 0%, #101010 38%, #080808 100%)',
        color: '#ffffff',
        padding: 24,
      }}
    >
      <div
        style={{
          width: 'min(1500px, 100%)',
          margin: '0 auto',
          display: 'grid',
          gridTemplateColumns: '260px minmax(0, 1fr)',
          gap: 22,
          alignItems: 'start',
        }}
      >
        <OwnerNavigation active="members" />

        <section
          style={{
            display: 'grid',
            gap: 20,
            minWidth: 0,
          }}
        >
          <header
            style={{
              padding: 24,
              borderRadius: 24,
              border: '1px solid #303030',
              background:
                'linear-gradient(145deg, rgba(28, 28, 28, 0.97), rgba(15, 15, 15, 0.97))',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: 18,
              flexWrap: 'wrap',
            }}
          >
            <div>
              <p
                style={{
                  margin: 0,
                  color: '#f5a623',
                  fontWeight: 900,
                  fontSize: 13,
                  letterSpacing: '0.09em',
                }}
              >
                MEMBER CRM
              </p>

              <h1
                style={{
                  margin: '8px 0 6px',
                  fontSize: 'clamp(28px, 4vw, 44px)',
                }}
              >
                Member Manager
              </h1>

              <p
                style={{
                  margin: 0,
                  color: '#a9a9a9',
                  lineHeight: 1.6,
                }}
              >
                Search members, review loyalty activity and manage customer
                relationships.
              </p>
            </div>

            <Link
              href="/scanner"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 9,
                padding: '13px 18px',
                borderRadius: 14,
                background: '#f5a623',
                color: '#111111',
                textDecoration: 'none',
                fontWeight: 900,
              }}
            >
              <ScanLine size={19} />
              Open scanner
            </Link>
          </header>

          <section
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
              gap: 14,
            }}
          >
            <MetricCard
              icon={<Users size={20} />}
              label="Total members"
              value={formatNumber(totalMembers)}
            />

            <MetricCard
              icon={<ShieldCheck size={20} />}
              label="Active members"
              value={formatNumber(activeMembers)}
            />

            <MetricCard
              icon={<WalletCards size={20} />}
              label="Current points"
              value={formatNumber(totalCurrentPoints)}
            />

            <MetricCard
              icon={<Sparkles size={20} />}
              label="Lifetime points"
              value={formatNumber(totalLifetimePoints)}
            />

            <MetricCard
              icon={<Activity size={20} />}
              label="Total visits"
              value={formatNumber(totalVisits)}
            />

            <MetricCard
              icon={<CreditCard size={20} />}
              label="Tracked spend"
              value={formatCurrency(totalSpent)}
            />
          </section>

          <form
            method="GET"
            style={{
              padding: 16,
              borderRadius: 18,
              border: '1px solid #303030',
              background: '#141414',
              display: 'flex',
              gap: 10,
              alignItems: 'center',
              flexWrap: 'wrap',
            }}
          >
            <div
              style={{
                flex: '1 1 300px',
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                padding: '0 14px',
                borderRadius: 14,
                border: '1px solid #383838',
                background: '#0e0e0e',
              }}
            >
              <Search size={18} color="#8f8f8f" />

              <input
                name="search"
                defaultValue={search}
                placeholder="Search name, phone, email or QR code"
                style={{
                  width: '100%',
                  border: 0,
                  outline: 0,
                  padding: '14px 0',
                  background: 'transparent',
                  color: '#ffffff',
                  fontSize: 15,
                }}
              />
            </div>

            <button
              type="submit"
              style={{
                border: 0,
                borderRadius: 14,
                padding: '14px 19px',
                background: '#f5a623',
                color: '#111111',
                fontWeight: 900,
                cursor: 'pointer',
              }}
            >
              Search
            </button>

            {search ? (
              <Link
                href="/owner/members"
                style={{
                  padding: '13px 16px',
                  borderRadius: 14,
                  border: '1px solid #383838',
                  color: '#ffffff',
                  textDecoration: 'none',
                  fontWeight: 800,
                }}
              >
                Clear
              </Link>
            ) : null}
          </form>

          <section
            style={{
              display: 'grid',
              gridTemplateColumns:
                'minmax(300px, 0.85fr) minmax(420px, 1.4fr)',
              gap: 18,
              alignItems: 'start',
            }}
          >
            <div
              style={{
                borderRadius: 22,
                border: '1px solid #303030',
                background: '#121212',
                overflow: 'hidden',
              }}
            >
              <div
                style={{
                  padding: 18,
                  borderBottom: '1px solid #292929',
                  display: 'flex',
                  justifyContent: 'space-between',
                  gap: 10,
                  alignItems: 'center',
                }}
              >
                <div>
                  <h2
                    style={{
                      margin: 0,
                      fontSize: 19,
                    }}
                  >
                    Members
                  </h2>

                  <p
                    style={{
                      margin: '5px 0 0',
                      color: '#8d8d8d',
                      fontSize: 13,
                    }}
                  >
                    {formatNumber(members.length)} result
                    {members.length === 1 ? '' : 's'}
                  </p>
                </div>

                <Users size={20} color="#f5a623" />
              </div>

              <div
                style={{
                  display: 'grid',
                  maxHeight: 760,
                  overflowY: 'auto',
                }}
              >
                {members.length === 0 ? (
                  <div
                    style={{
                      padding: 28,
                      color: '#999999',
                      textAlign: 'center',
                    }}
                  >
                    No members matched your search.
                  </div>
                ) : (
                  members.map((member) => {
                    const isSelected =
                      selectedMember?.id === member.id;

                    const memberHref = search
                      ? `/owner/members?search=${encodeURIComponent(
                          search,
                        )}&member=${encodeURIComponent(member.id)}`
                      : `/owner/members?member=${encodeURIComponent(
                          member.id,
                        )}`;

                    return (
                      <Link
                        key={member.id}
                        href={memberHref}
                        style={{
                          padding: 16,
                          borderBottom: '1px solid #252525',
                          background: isSelected
                            ? 'rgba(245, 166, 35, 0.1)'
                            : 'transparent',
                          color: '#ffffff',
                          textDecoration: 'none',
                          display: 'grid',
                          gridTemplateColumns: '48px minmax(0, 1fr) auto',
                          alignItems: 'center',
                          gap: 12,
                        }}
                      >
                        <div
                          style={{
                            width: 48,
                            height: 48,
                            borderRadius: 16,
                            display: 'grid',
                            placeItems: 'center',
                            background: isSelected
                              ? '#f5a623'
                              : '#242424',
                            color: isSelected
                              ? '#111111'
                              : '#ffffff',
                            fontWeight: 900,
                          }}
                        >
                          {getInitials(member.full_name)}
                        </div>

                        <div
                          style={{
                            minWidth: 0,
                          }}
                        >
                          <p
                            style={{
                              margin: 0,
                              fontWeight: 900,
                              overflow: 'hidden',
                              whiteSpace: 'nowrap',
                              textOverflow: 'ellipsis',
                            }}
                          >
                            {member.full_name || 'Unnamed member'}
                          </p>

                          <p
                            style={{
                              margin: '5px 0 0',
                              color: '#999999',
                              fontSize: 13,
                              overflow: 'hidden',
                              whiteSpace: 'nowrap',
                              textOverflow: 'ellipsis',
                            }}
                          >
                            {member.phone ||
                              member.email ||
                              'No contact information'}
                          </p>
                        </div>

                        <div
                          style={{
                            textAlign: 'right',
                          }}
                        >
                          <p
                            style={{
                              margin: 0,
                              color: '#f5a623',
                              fontWeight: 900,
                            }}
                          >
                            {formatNumber(member.points)}
                          </p>

                          <p
                            style={{
                              margin: '4px 0 0',
                              color: '#777777',
                              fontSize: 11,
                            }}
                          >
                            POINTS
                          </p>
                        </div>
                      </Link>
                    );
                  })
                )}
              </div>
            </div>

            <div
              style={{
                display: 'grid',
                gap: 18,
              }}
            >
              {selectedMember ? (
                <>
                  <section
                    style={{
                      padding: 22,
                      borderRadius: 22,
                      border: '1px solid #303030',
                      background:
                        'linear-gradient(145deg, #191919, #111111)',
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        gap: 18,
                        alignItems: 'flex-start',
                        flexWrap: 'wrap',
                      }}
                    >
                      <div
                        style={{
                          display: 'flex',
                          gap: 15,
                          alignItems: 'center',
                        }}
                      >
                        <div
                          style={{
                            width: 66,
                            height: 66,
                            borderRadius: 21,
                            display: 'grid',
                            placeItems: 'center',
                            background: '#f5a623',
                            color: '#111111',
                            fontWeight: 950,
                            fontSize: 21,
                          }}
                        >
                          {getInitials(selectedMember.full_name)}
                        </div>

                        <div>
                          <div
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              gap: 8,
                              flexWrap: 'wrap',
                            }}
                          >
                            <h2
                              style={{
                                margin: 0,
                                fontSize: 25,
                              }}
                            >
                              {selectedMember.full_name ||
                                'Unnamed member'}
                            </h2>

                            {selectedMember.is_active ? (
                              <BadgeCheck
                                size={20}
                                color="#4ade80"
                              />
                            ) : null}
                          </div>

                          <p
                            style={{
                              margin: '7px 0 0',
                              color: '#f5a623',
                              fontWeight: 900,
                            }}
                          >
                            {getMembershipLabel(
                              selectedMember.membership_level,
                            )}
                          </p>
                        </div>
                      </div>

                      <span
                        style={{
                          padding: '8px 12px',
                          borderRadius: 999,
                          background: selectedMember.is_active
                            ? 'rgba(74, 222, 128, 0.12)'
                            : 'rgba(248, 113, 113, 0.12)',
                          color: selectedMember.is_active
                            ? '#4ade80'
                            : '#f87171',
                          border: selectedMember.is_active
                            ? '1px solid rgba(74, 222, 128, 0.35)'
                            : '1px solid rgba(248, 113, 113, 0.35)',
                          fontSize: 12,
                          fontWeight: 900,
                        }}
                      >
                        {selectedMember.is_active
                          ? 'ACTIVE'
                          : 'INACTIVE'}
                      </span>
                    </div>

                    <div
                      style={{
                        marginTop: 22,
                        display: 'grid',
                        gridTemplateColumns:
                          'repeat(auto-fit, minmax(135px, 1fr))',
                        gap: 12,
                      }}
                    >
                      <ProfileMetric
                        label="Current points"
                        value={formatNumber(selectedMember.points)}
                      />

                      <ProfileMetric
                        label="Lifetime points"
                        value={formatNumber(
                          selectedMember.lifetime_points,
                        )}
                      />

                      <ProfileMetric
                        label="Total visits"
                        value={formatNumber(
                          selectedMember.total_visits,
                        )}
                      />

                      <ProfileMetric
                        label="Total spent"
                        value={formatCurrency(
                          selectedMember.total_spent,
                        )}
                      />
                    </div>

                    <div
                      style={{
                        marginTop: 20,
                        display: 'grid',
                        gridTemplateColumns:
                          'repeat(auto-fit, minmax(220px, 1fr))',
                        gap: 12,
                      }}
                    >
                      <InfoRow
                        icon={<Phone size={17} />}
                        label="Phone"
                        value={selectedMember.phone || 'Not provided'}
                      />

                      <InfoRow
                        icon={<Mail size={17} />}
                        label="Email"
                        value={selectedMember.email || 'Not provided'}
                      />

                      <InfoRow
                        icon={<CalendarDays size={17} />}
                        label="Birthday"
                        value={formatDate(selectedMember.birthday)}
                      />

                      <InfoRow
                        icon={<Activity size={17} />}
                        label="Last visit"
                        value={formatDateTime(
                          selectedMember.last_visit_at,
                        )}
                      />

                      <InfoRow
                        icon={<UserRound size={17} />}
                        label="Member since"
                        value={formatDate(selectedMember.created_at)}
                      />

                      <InfoRow
                        icon={<QrCode size={17} />}
                        label="QR code"
                        value={
                          selectedMember.qr_code || 'Not generated'
                        }
                      />
                    </div>

                    <div
                      style={{
                        marginTop: 20,
                        display: 'flex',
                        gap: 10,
                        flexWrap: 'wrap',
                      }}
                    >
                      <Link
                        href="/scanner"
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 8,
                          padding: '12px 15px',
                          borderRadius: 13,
                          background: '#f5a623',
                          color: '#111111',
                          textDecoration: 'none',
                          fontWeight: 900,
                        }}
                      >
                        <ScanLine size={18} />
                        Award points
                      </Link>

                      <Link
                        href={`/scanner?code=${encodeURIComponent(
                          selectedMember.qr_code || '',
                        )}`}
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 8,
                          padding: '12px 15px',
                          borderRadius: 13,
                          border: '1px solid #3a3a3a',
                          color: '#ffffff',
                          textDecoration: 'none',
                          fontWeight: 800,
                        }}
                      >
                        <QrCode size={18} />
                        Open QR profile
                      </Link>
                    </div>
                  </section>

                  <section
                    style={{
                      borderRadius: 22,
                      border: '1px solid #303030',
                      background: '#121212',
                      overflow: 'hidden',
                    }}
                  >
                    <div
                      style={{
                        padding: 19,
                        borderBottom: '1px solid #292929',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        gap: 12,
                      }}
                    >
                      <div>
                        <h2
                          style={{
                            margin: 0,
                            fontSize: 19,
                          }}
                        >
                          Recent Activity
                        </h2>

                        <p
                          style={{
                            margin: '5px 0 0',
                            color: '#8d8d8d',
                            fontSize: 13,
                          }}
                        >
                          Latest points transactions for this member
                        </p>
                      </div>

                      <Activity size={20} color="#f5a623" />
                    </div>

                    <div
                      style={{
                        display: 'grid',
                      }}
                    >
                      {transactions.length === 0 ? (
                        <div
                          style={{
                            padding: 28,
                            textAlign: 'center',
                            color: '#8f8f8f',
                          }}
                        >
                          No transaction history yet.
                        </div>
                      ) : (
                        transactions.map((transaction, index) => {
                          const points =
                            getTransactionPoints(transaction);
                          const positive = points >= 0;

                          return (
                            <div
                              key={
                                transaction.id ??
                                `${transaction.created_at}-${index}`
                              }
                              style={{
                                padding: 17,
                                borderBottom:
                                  index === transactions.length - 1
                                    ? 'none'
                                    : '1px solid #252525',
                                display: 'grid',
                                gridTemplateColumns:
                                  '42px minmax(0, 1fr) auto',
                                gap: 12,
                                alignItems: 'center',
                              }}
                            >
                              <div
                                style={{
                                  width: 42,
                                  height: 42,
                                  borderRadius: 14,
                                  display: 'grid',
                                  placeItems: 'center',
                                  background: positive
                                    ? 'rgba(74, 222, 128, 0.12)'
                                    : 'rgba(248, 113, 113, 0.12)',
                                  color: positive
                                    ? '#4ade80'
                                    : '#f87171',
                                }}
                              >
                                <Sparkles size={18} />
                              </div>

                              <div>
                                <p
                                  style={{
                                    margin: 0,
                                    fontWeight: 850,
                                  }}
                                >
                                  {getTransactionTitle(transaction)}
                                </p>

                                <p
                                  style={{
                                    margin: '5px 0 0',
                                    color: '#858585',
                                    fontSize: 13,
                                  }}
                                >
                                  {formatDateTime(
                                    transaction.created_at,
                                  )}
                                </p>
                              </div>

                              <strong
                                style={{
                                  color: positive
                                    ? '#4ade80'
                                    : '#f87171',
                                  fontSize: 16,
                                }}
                              >
                                {positive ? '+' : ''}
                                {formatNumber(points)}
                              </strong>
                            </div>
                          );
                        })
                      )}
                    </div>
                  </section>
                </>
              ) : (
                <section
                  style={{
                    minHeight: 420,
                    padding: 28,
                    borderRadius: 22,
                    border: '1px solid #303030',
                    background: '#121212',
                    display: 'grid',
                    placeItems: 'center',
                    textAlign: 'center',
                  }}
                >
                  <div>
                    <UserRound
                      size={42}
                      color="#f5a623"
                      style={{
                        marginBottom: 14,
                      }}
                    />

                    <h2
                      style={{
                        margin: 0,
                      }}
                    >
                      Select a member
                    </h2>

                    <p
                      style={{
                        margin: '9px 0 0',
                        color: '#909090',
                      }}
                    >
                      Choose a member from the list to open their CRM
                      profile.
                    </p>
                  </div>
                </section>
              )}

              <Link
                href="/owner/analytics"
                style={{
                  padding: 17,
                  borderRadius: 18,
                  border: '1px solid #303030',
                  background: '#151515',
                  color: '#ffffff',
                  textDecoration: 'none',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: 12,
                  fontWeight: 850,
                }}
              >
                View complete loyalty analytics
                <ArrowRight size={18} color="#f5a623" />
              </Link>
            </div>
          </section>
        </section>
      </div>
    </main>
  );
}

function MetricCard({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <article
      style={{
        padding: 18,
        borderRadius: 18,
        border: '1px solid #303030',
        background: '#141414',
      }}
    >
      <div
        style={{
          width: 38,
          height: 38,
          borderRadius: 12,
          display: 'grid',
          placeItems: 'center',
          color: '#f5a623',
          background: 'rgba(245, 166, 35, 0.1)',
        }}
      >
        {icon}
      </div>

      <p
        style={{
          margin: '15px 0 5px',
          color: '#8e8e8e',
          fontSize: 13,
          fontWeight: 800,
        }}
      >
        {label}
      </p>

      <strong
        style={{
          fontSize: 23,
        }}
      >
        {value}
      </strong>
    </article>
  );
}

function ProfileMetric({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div
      style={{
        padding: 15,
        borderRadius: 16,
        border: '1px solid #303030',
        background: '#101010',
      }}
    >
      <p
        style={{
          margin: 0,
          color: '#888888',
          fontSize: 12,
          fontWeight: 800,
        }}
      >
        {label}
      </p>

      <strong
        style={{
          display: 'block',
          marginTop: 7,
          fontSize: 19,
          color: '#ffffff',
        }}
      >
        {value}
      </strong>
    </div>
  );
}

function InfoRow({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div
      style={{
        padding: 14,
        borderRadius: 15,
        border: '1px solid #2d2d2d',
        background: '#121212',
        display: 'flex',
        gap: 11,
        alignItems: 'flex-start',
        minWidth: 0,
      }}
    >
      <span
        style={{
          color: '#f5a623',
          marginTop: 2,
          flexShrink: 0,
        }}
      >
        {icon}
      </span>

      <div
        style={{
          minWidth: 0,
        }}
      >
        <p
          style={{
            margin: 0,
            color: '#838383',
            fontSize: 12,
            fontWeight: 800,
          }}
        >
          {label}
        </p>

        <p
          style={{
            margin: '5px 0 0',
            color: '#ffffff',
            fontSize: 14,
            wordBreak: 'break-word',
          }}
        >
          {value}
        </p>
      </div>
    </div>
  );
}