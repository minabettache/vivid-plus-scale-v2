import { NextResponse } from "next/server";
import { requireOwner } from "@/lib/auth/require-owner";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type DatabaseRow = Record<string, unknown>;

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === "object" && error !== null) {
    const possibleError = error as {
      message?: unknown;
      details?: unknown;
      hint?: unknown;
      code?: unknown;
    };

    const parts = [
      typeof possibleError.message === "string"
        ? possibleError.message
        : null,
      typeof possibleError.details === "string"
        ? possibleError.details
        : null,
      typeof possibleError.hint === "string"
        ? possibleError.hint
        : null,
      typeof possibleError.code === "string"
        ? `Code: ${possibleError.code}`
        : null,
    ].filter(Boolean);

    if (parts.length > 0) {
      return parts.join(" | ");
    }
  }

  return "Unexpected server error.";
}

function numberValue(value: unknown) {
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

function stringValue(...values: unknown[]) {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }

  return "";
}

function dateValue(...values: unknown[]) {
  for (const value of values) {
    if (typeof value !== "string" || !value.trim()) {
      continue;
    }

    const date = new Date(value);

    if (!Number.isNaN(date.getTime())) {
      return date;
    }
  }

  return null;
}

function getOrlandoDayStart(reference = new Date()) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });

  const parts = Object.fromEntries(
    formatter
      .formatToParts(reference)
      .map((part) => [part.type, part.value]),
  );

  const localRepresentation = new Date(
    `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}`,
  );

  const timezoneOffset =
    reference.getTime() - localRepresentation.getTime();

  const localMidnight = new Date(
    `${parts.year}-${parts.month}-${parts.day}T00:00:00`,
  );

  return new Date(localMidnight.getTime() + timezoneOffset);
}

function isPublished(row: DatabaseRow) {
  return (
    row.is_published === true ||
    row.is_active === true ||
    row.active === true
  );
}

function isActivePromotion(
  row: DatabaseRow,
  now: Date,
) {
  if (!isPublished(row)) {
    return false;
  }

  const startAt = dateValue(
    row.start_at,
    row.starts_at,
    row.start_date,
  );

  const endAt = dateValue(
    row.end_at,
    row.ends_at,
    row.end_date,
  );

  if (startAt && startAt > now) {
    return false;
  }

  if (endAt && endAt < now) {
    return false;
  }

  return true;
}

function isUpcomingEvent(
  row: DatabaseRow,
  now: Date,
) {
  const eventDate = dateValue(
    row.start_at,
    row.starts_at,
    row.event_at,
    row.event_date,
    row.date,
  );

  if (!eventDate) {
    return isPublished(row);
  }

  return eventDate >= now;
}

function ownerErrorResponse(error: unknown) {
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
    message === "STAFF_ACCESS_REQUIRED" ||
    message === "OWNER_ACCESS_REQUIRED"
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

  console.error("Owner dashboard error:", error);

  return NextResponse.json(
    {
      error: message,
    },
    {
      status: 500,
    },
  );
}

export async function GET() {
  try {
    const { staff } = await requireOwner();
    const supabase = await createClient();

    const now = new Date();
    const todayStart = getOrlandoDayStart(now);

    const [
      salesResult,
      membersResult,
      promotionsResult,
      eventsResult,
      redemptionsResult,
    ] = await Promise.all([
      supabase
        .from("member_sales")
        .select("*")
        .gte("created_at", todayStart.toISOString())
        .order("created_at", {
          ascending: false,
        })
        .limit(500),

      supabase
        .from("members")
        .select("*")
        .order("created_at", {
          ascending: false,
        })
        .limit(2500),

      supabase
        .from("promotions")
        .select("*")
        .order("created_at", {
          ascending: false,
        })
        .limit(500),

      supabase
        .from("events")
        .select("*")
        .order("created_at", {
          ascending: false,
        })
        .limit(500),

      supabase
        .from("reward_redemptions")
        .select("*")
        .gte("created_at", todayStart.toISOString())
        .order("created_at", {
          ascending: false,
        })
        .limit(500),
    ]);

    const queryErrors = [
      salesResult.error,
      membersResult.error,
      promotionsResult.error,
      eventsResult.error,
      redemptionsResult.error,
    ].filter(Boolean);

    if (queryErrors.length > 0) {
      throw queryErrors[0];
    }

    const sales =
      (salesResult.data ?? []) as DatabaseRow[];

    const members =
      (membersResult.data ?? []) as DatabaseRow[];

    const promotions =
      (promotionsResult.data ?? []) as DatabaseRow[];

    const events =
      (eventsResult.data ?? []) as DatabaseRow[];

    const redemptions =
      (redemptionsResult.data ?? []) as DatabaseRow[];

    const revenueToday = sales.reduce(
      (total, sale) =>
        total +
        numberValue(
          sale.amount_paid ??
            sale.total_amount ??
            sale.amount,
        ),
      0,
    );

    const activeMembers = members.filter(
      (member) => member.is_active !== false,
    );

    const newMembersToday = members.filter(
      (member) => {
        const createdAt = dateValue(member.created_at);

        return (
          createdAt !== null &&
          createdAt >= todayStart
        );
      },
    );

    const activePromotions = promotions.filter(
      (promotion) =>
        isActivePromotion(promotion, now),
    );

    const upcomingEvents = events.filter((event) =>
      isUpcomingEvent(event, now),
    );

    const uniqueVisitors = new Set(
      sales
        .map((sale) =>
          stringValue(
            sale.member_id,
            sale.customer_id,
          ),
        )
        .filter(Boolean),
    );

    const latestSales = sales
      .slice(0, 10)
      .map((sale) => ({
        id:
          stringValue(sale.id, sale.sale_id) ||
          crypto.randomUUID(),

        memberId:
          stringValue(
            sale.member_id,
            sale.customer_id,
          ) || null,

        memberName:
          stringValue(
            sale.member_name,
            sale.customer_name,
            sale.full_name,
          ) || "VIVID+ Member",

        amount: numberValue(
          sale.amount_paid ??
            sale.total_amount ??
            sale.amount,
        ),

        pointsEarned: numberValue(
          sale.points_earned ??
            sale.points_awarded ??
            sale.points,
        ),

        paymentMethod:
          stringValue(
            sale.payment_method,
            sale.payment_type,
          ) || "unknown",

        createdAt:
          dateValue(
            sale.created_at,
            sale.sale_at,
            sale.completed_at,
          )?.toISOString() ?? null,
      }));

    const averageTicket =
      sales.length > 0
        ? revenueToday / sales.length
        : 0;

    const pointsAwardedToday = latestSales.reduce(
      (total, sale) =>
        total + sale.pointsEarned,
      0,
    );

    return NextResponse.json(
      {
        generatedAt: now.toISOString(),
        timezone: "America/New_York",

        owner: {
          id: staff.id,
          role: staff.role,
        },

        summary: {
          revenueToday: Number(
            revenueToday.toFixed(2),
          ),

          salesToday: sales.length,

          visitsToday: sales.length,

          uniqueVisitorsToday:
            uniqueVisitors.size,

          averageTicket: Number(
            averageTicket.toFixed(2),
          ),

          pointsAwardedToday,

          totalMembers: members.length,

          activeMembers: activeMembers.length,

          newMembersToday:
            newMembersToday.length,

          activePromotions:
            activePromotions.length,

          upcomingEvents:
            upcomingEvents.length,

          rewardRedemptionsToday:
            redemptions.length,
        },

        latestSales,

        activePromotions:
          activePromotions.slice(0, 8),

        upcomingEvents:
          upcomingEvents.slice(0, 8),

        recentRedemptions:
          redemptions.slice(0, 8),
      },
      {
        headers: {
          "Cache-Control":
            "private, no-store, no-cache, must-revalidate",
        },
      },
    );
  } catch (error) {
    return ownerErrorResponse(error);
  }
}