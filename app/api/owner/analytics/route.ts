import { NextResponse } from "next/server";
import { requireOwner } from "@/lib/auth/require-owner";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const BUSINESS_TIMEZONE = "America/New_York";
const BUSINESS_DAY_CUTOFF_HOUR = 4;

type DatabaseRow = Record<string, unknown>;

function numberValue(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string") {
    const parsed = Number(value);

    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return 0;
}

function stringValue(...values: unknown[]): string {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }

    if (typeof value === "number" && Number.isFinite(value)) {
      return String(value);
    }
  }

  return "";
}

function dateValue(...values: unknown[]): Date | null {
  for (const value of values) {
    if (typeof value !== "string" || !value.trim()) {
      continue;
    }

    const parsed = new Date(value);

    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }

  return null;
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === "object" && error !== null) {
    const databaseError = error as {
      message?: unknown;
      details?: unknown;
      hint?: unknown;
      code?: unknown;
    };

    const parts = [
      typeof databaseError.message === "string"
        ? databaseError.message
        : null,

      typeof databaseError.details === "string"
        ? databaseError.details
        : null,

      typeof databaseError.hint === "string"
        ? databaseError.hint
        : null,

      typeof databaseError.code === "string"
        ? `Code: ${databaseError.code}`
        : null,
    ].filter(Boolean);

    if (parts.length > 0) {
      return parts.join(" | ");
    }
  }

  return "Unexpected server error.";
}

function errorResponse(error: unknown) {
  const message = getErrorMessage(error);

  if (message === "UNAUTHENTICATED") {
    return NextResponse.json(
      {
        error: "Please sign in.",
      },
      {
        status: 401,
      },
    );
  }

  if (
    message === "OWNER_ACCESS_REQUIRED" ||
    message === "STAFF_ACCESS_REQUIRED"
  ) {
    return NextResponse.json(
      {
        error: "Owner access is required.",
      },
      {
        status: 403,
      },
    );
  }

  console.error("Owner analytics API error:", error);

  return NextResponse.json(
    {
      error: message,
    },
    {
      status: 500,
    },
  );
}

function getBusinessDayKey(date: Date): string {
  const shiftedDate = new Date(
    date.getTime() -
      BUSINESS_DAY_CUTOFF_HOUR * 60 * 60 * 1000,
  );

  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: BUSINESS_TIMEZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(shiftedDate);

  const values = Object.fromEntries(
    parts.map((part) => [part.type, part.value]),
  );

  return `${values.year}-${values.month}-${values.day}`;
}

function getPreviousBusinessDayKey(date: Date): string {
  const previousDay = new Date(
    date.getTime() - 24 * 60 * 60 * 1000,
  );

  return getBusinessDayKey(previousDay);
}

function belongsToBusinessDay(
  value: unknown,
  businessDayKey: string,
): boolean {
  const date = dateValue(value);

  if (!date) {
    return false;
  }

  return getBusinessDayKey(date) === businessDayKey;
}

function getOrlandoHour(date: Date): number {
  const hourText = new Intl.DateTimeFormat("en-US", {
    timeZone: BUSINESS_TIMEZONE,
    hour: "2-digit",
    hourCycle: "h23",
  }).format(date);

  return Number(hourText);
}

function formatHour(hour: number): string {
  const normalizedHour = hour % 24;

  if (normalizedHour === 0) {
    return "12 AM";
  }

  if (normalizedHour === 12) {
    return "12 PM";
  }

  if (normalizedHour < 12) {
    return `${normalizedHour} AM`;
  }

  return `${normalizedHour - 12} PM`;
}

function getSaleDate(sale: DatabaseRow): Date | null {
  return dateValue(
    sale.created_at,
    sale.sale_at,
    sale.completed_at,
  );
}

function getSaleAmount(sale: DatabaseRow): number {
  return numberValue(
    sale.amount_paid ??
      sale.total_amount ??
      sale.amount,
  );
}

function getMemberName(member: DatabaseRow): string {
  const fullName = stringValue(
    member.full_name,
    member.name,
    member.display_name,
  );

  if (fullName) {
    return fullName;
  }

  const firstName = stringValue(
    member.first_name,
    member.firstname,
  );

  const lastName = stringValue(
    member.last_name,
    member.lastname,
  );

  const combinedName = `${firstName} ${lastName}`.trim();

  return (
    combinedName ||
    stringValue(member.email, member.phone) ||
    "VIVID+ Member"
  );
}

function normalizePaymentMethod(value: unknown): string {
  const method = stringValue(value).toLowerCase();

  if (!method) {
    return "other";
  }

  if (method.includes("cash")) {
    return "cash";
  }

  if (
    method.includes("card") ||
    method.includes("credit") ||
    method.includes("debit")
  ) {
    return "card";
  }

  if (
    method.includes("apple") ||
    method.includes("google") ||
    method.includes("tap")
  ) {
    return "digitalWallet";
  }

  return "other";
}

export async function GET() {
  try {
    const { staff } = await requireOwner();
    const supabase = await createClient();

    const now = new Date();
    const todayBusinessDay = getBusinessDayKey(now);
    const yesterdayBusinessDay =
      getPreviousBusinessDayKey(now);

    const historyStart = new Date(
      now.getTime() - 8 * 24 * 60 * 60 * 1000,
    );

    const [salesResult, membersResult] =
      await Promise.all([
        supabase
          .from("member_sales")
          .select("*")
          .gte(
            "created_at",
            historyStart.toISOString(),
          )
          .order("created_at", {
            ascending: false,
          })
          .limit(5000),

        supabase
          .from("members")
          .select("*")
          .limit(5000),
      ]);

    const queryError =
      salesResult.error || membersResult.error;

    if (queryError) {
      throw queryError;
    }

    const sales =
      (salesResult.data ?? []) as DatabaseRow[];

    const members =
      (membersResult.data ?? []) as DatabaseRow[];

    const memberById = new Map<string, DatabaseRow>();

    for (const member of members) {
      const memberId = stringValue(
        member.id,
        member.member_id,
      );

      if (memberId) {
        memberById.set(memberId, member);
      }
    }

    const salesToday = sales.filter((sale) =>
      belongsToBusinessDay(
        sale.created_at ??
          sale.sale_at ??
          sale.completed_at,
        todayBusinessDay,
      ),
    );

    const salesYesterday = sales.filter((sale) =>
      belongsToBusinessDay(
        sale.created_at ??
          sale.sale_at ??
          sale.completed_at,
        yesterdayBusinessDay,
      ),
    );

    const revenueToday = salesToday.reduce(
      (total, sale) => total + getSaleAmount(sale),
      0,
    );

    const revenueYesterday = salesYesterday.reduce(
      (total, sale) => total + getSaleAmount(sale),
      0,
    );

    const percentageChange =
      revenueYesterday > 0
        ? ((revenueToday - revenueYesterday) /
            revenueYesterday) *
          100
        : revenueToday > 0
          ? 100
          : 0;

    const hourlyMap = new Map<
      number,
      {
        revenue: number;
        sales: number;
      }
    >();

    for (let index = 0; index < 24; index += 1) {
      const hour =
        (BUSINESS_DAY_CUTOFF_HOUR + index) % 24;

      hourlyMap.set(hour, {
        revenue: 0,
        sales: 0,
      });
    }

    for (const sale of salesToday) {
      const saleDate = getSaleDate(sale);

      if (!saleDate) {
        continue;
      }

      const hour = getOrlandoHour(saleDate);
      const current = hourlyMap.get(hour);

      if (!current) {
        continue;
      }

      current.revenue += getSaleAmount(sale);
      current.sales += 1;
    }

    const hourlySales = Array.from(
      hourlyMap.entries(),
    ).map(([hour, totals]) => ({
      hour,
      label: formatHour(hour),
      revenue: Number(totals.revenue.toFixed(2)),
      sales: totals.sales,
    }));

    const paymentMethods = {
      cash: {
        revenue: 0,
        sales: 0,
      },
      card: {
        revenue: 0,
        sales: 0,
      },
      digitalWallet: {
        revenue: 0,
        sales: 0,
      },
      other: {
        revenue: 0,
        sales: 0,
      },
    };

    for (const sale of salesToday) {
      const method = normalizePaymentMethod(
        sale.payment_method ??
          sale.payment_type,
      );

      paymentMethods[method].revenue +=
        getSaleAmount(sale);

      paymentMethods[method].sales += 1;
    }

    const memberSpending = new Map<
      string,
      {
        memberId: string;
        memberName: string;
        revenue: number;
        visits: number;
        pointsEarned: number;
      }
    >();

    for (const sale of sales) {
      const memberId = stringValue(
        sale.member_id,
        sale.customer_id,
      );

      if (!memberId) {
        continue;
      }

      const member = memberById.get(memberId);

      const existing = memberSpending.get(memberId) ?? {
        memberId,
        memberName:
          stringValue(
            sale.member_name,
            sale.customer_name,
            sale.full_name,
          ) ||
          (member
            ? getMemberName(member)
            : "VIVID+ Member"),
        revenue: 0,
        visits: 0,
        pointsEarned: 0,
      };

      existing.revenue += getSaleAmount(sale);
      existing.visits += 1;
      existing.pointsEarned += numberValue(
        sale.points_earned ??
          sale.points_awarded ??
          sale.points,
      );

      memberSpending.set(memberId, existing);
    }

    const topMembers = Array.from(
      memberSpending.values(),
    )
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 10)
      .map((member, index) => ({
        rank: index + 1,
        memberId: member.memberId,
        memberName: member.memberName,
        revenue: Number(member.revenue.toFixed(2)),
        visits: member.visits,
        pointsEarned: member.pointsEarned,
      }));

    const dailyTrend = Array.from(
      { length: 7 },
      (_, index) => {
        const date = new Date(
          now.getTime() -
            (6 - index) * 24 * 60 * 60 * 1000,
        );

        const businessDay = getBusinessDayKey(date);

        const daySales = sales.filter((sale) =>
          belongsToBusinessDay(
            sale.created_at ??
              sale.sale_at ??
              sale.completed_at,
            businessDay,
          ),
        );

        const revenue = daySales.reduce(
          (total, sale) =>
            total + getSaleAmount(sale),
          0,
        );

        const label =
          new Intl.DateTimeFormat("en-US", {
            timeZone: BUSINESS_TIMEZONE,
            weekday: "short",
          }).format(date);

        return {
          businessDay,
          label,
          revenue: Number(revenue.toFixed(2)),
          sales: daySales.length,
        };
      },
    );

    return NextResponse.json(
      {
        generatedAt: now.toISOString(),
        timezone: BUSINESS_TIMEZONE,
        businessDayCutoffHour:
          BUSINESS_DAY_CUTOFF_HOUR,
        businessDay: todayBusinessDay,

        owner: {
          id: staff.id,
          role: staff.role,
        },

        comparison: {
          revenueToday: Number(
            revenueToday.toFixed(2),
          ),
          revenueYesterday: Number(
            revenueYesterday.toFixed(2),
          ),
          difference: Number(
            (
              revenueToday - revenueYesterday
            ).toFixed(2),
          ),
          percentageChange: Number(
            percentageChange.toFixed(1),
          ),
        },

        hourlySales,

        paymentMethods: {
          cash: {
            revenue: Number(
              paymentMethods.cash.revenue.toFixed(2),
            ),
            sales: paymentMethods.cash.sales,
          },

          card: {
            revenue: Number(
              paymentMethods.card.revenue.toFixed(2),
            ),
            sales: paymentMethods.card.sales,
          },

          digitalWallet: {
            revenue: Number(
              paymentMethods.digitalWallet.revenue.toFixed(
                2,
              ),
            ),
            sales:
              paymentMethods.digitalWallet.sales,
          },

          other: {
            revenue: Number(
              paymentMethods.other.revenue.toFixed(2),
            ),
            sales: paymentMethods.other.sales,
          },
        },

        topMembers,
        dailyTrend,
      },
      {
        headers: {
          "Cache-Control":
            "private, no-store, no-cache, must-revalidate",
        },
      },
    );
  } catch (error) {
    return errorResponse(error);
  }
}