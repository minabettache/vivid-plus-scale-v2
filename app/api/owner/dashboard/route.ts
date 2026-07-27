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

/**
 * VIVID+ business day:
 *
 * The lounge business day changes at 4:00 AM Orlando time,
 * instead of changing at midnight.
 *
 * Example:
 * Saturday 10:59 PM = Saturday
 * Sunday 1:30 AM = still Saturday
 * Sunday 4:00 AM = Sunday
 */
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

function isPublished(row: DatabaseRow): boolean {
  return (
    row.is_active === true ||
    row.is_published === true ||
    row.active === true
  );
}

function isActivePromotion(
  promotion: DatabaseRow,
  now: Date,
): boolean {
  if (!isPublished(promotion)) {
    return false;
  }

  const startsAt = dateValue(
    promotion.starts_at,
    promotion.start_at,
    promotion.start_date,
  );

  const endsAt = dateValue(
    promotion.ends_at,
    promotion.end_at,
    promotion.end_date,
  );

  if (startsAt && startsAt > now) {
    return false;
  }

  if (endsAt && endsAt < now) {
    return false;
  }

  return true;
}

function isUpcomingEvent(
  event: DatabaseRow,
  now: Date,
): boolean {
  const eventDate = dateValue(
    event.starts_at,
    event.start_at,
    event.event_at,
    event.event_date,
    event.date,
  );

  if (!eventDate) {
    return isPublished(event);
  }

  return eventDate >= now;
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

  console.error("Owner dashboard API error:", error);

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
    const businessDay = getBusinessDayKey(now);

    /*
     * Fetch the most recent 48 hours.
     * We then filter using Orlando's 4:00 AM business-day cutoff.
     */
    const recentActivityStart = new Date(
      now.getTime() - 48 * 60 * 60 * 1000,
    );

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
        .gte(
          "created_at",
          recentActivityStart.toISOString(),
        )
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
        .gte(
          "created_at",
          recentActivityStart.toISOString(),
        )
        .order("created_at", {
          ascending: false,
        })
        .limit(500),
    ]);

    const queryError =
      salesResult.error ||
      membersResult.error ||
      promotionsResult.error ||
      eventsResult.error ||
      redemptionsResult.error;

    if (queryError) {
      throw queryError;
    }

    const allRecentSales =
      (salesResult.data ?? []) as DatabaseRow[];

    const members =
      (membersResult.data ?? []) as DatabaseRow[];

    const promotions =
      (promotionsResult.data ?? []) as DatabaseRow[];

    const events =
      (eventsResult.data ?? []) as DatabaseRow[];

    const allRecentRedemptions =
      (redemptionsResult.data ?? []) as DatabaseRow[];

    const salesToday = allRecentSales.filter((sale) =>
      belongsToBusinessDay(
        sale.created_at ??
          sale.sale_at ??
          sale.completed_at,
        businessDay,
      ),
    );

    const redemptionsToday =
      allRecentRedemptions.filter((redemption) =>
        belongsToBusinessDay(
          redemption.created_at ??
            redemption.redeemed_at ??
            redemption.completed_at,
          businessDay,
        ),
      );

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

    const revenueToday = salesToday.reduce(
      (total, sale) =>
        total +
        numberValue(
          sale.amount_paid ??
            sale.total_amount ??
            sale.amount,
        ),
      0,
    );

    const pointsAwardedToday = salesToday.reduce(
      (total, sale) =>
        total +
        numberValue(
          sale.points_earned ??
            sale.points_awarded ??
            sale.points,
        ),
      0,
    );

    const activeMembers = members.filter(
      (member) => member.is_active !== false,
    );

    const newMembersToday = members.filter((member) =>
      belongsToBusinessDay(
        member.created_at,
        businessDay,
      ),
    );

    const activePromotions = promotions.filter(
      (promotion) =>
        isActivePromotion(promotion, now),
    );

    const upcomingEvents = events.filter((event) =>
      isUpcomingEvent(event, now),
    );

    const uniqueVisitorIds = new Set(
      salesToday
        .map((sale) =>
          stringValue(
            sale.member_id,
            sale.customer_id,
          ),
        )
        .filter(Boolean),
    );

    const averageTicket =
      salesToday.length > 0
        ? revenueToday / salesToday.length
        : 0;

    const latestSales = salesToday
      .slice(0, 10)
      .map((sale) => {
        const memberId =
          stringValue(
            sale.member_id,
            sale.customer_id,
          ) || null;

        const member = memberId
          ? memberById.get(memberId)
          : undefined;

        return {
          id:
            stringValue(sale.id, sale.sale_id) ||
            crypto.randomUUID(),

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

          tier:
            stringValue(
              sale.tier_at_purchase,
              sale.tier,
            ) || null,

          note:
            stringValue(sale.note) || null,

          createdAt:
            dateValue(
              sale.created_at,
              sale.sale_at,
              sale.completed_at,
            )?.toISOString() ?? null,
        };
      });

    return NextResponse.json(
      {
        generatedAt: now.toISOString(),

        timezone: BUSINESS_TIMEZONE,

        businessDayCutoffHour:
          BUSINESS_DAY_CUTOFF_HOUR,

        businessDay,

        owner: {
          id: staff.id,
          role: staff.role,
        },

        summary: {
          revenueToday: Number(
            revenueToday.toFixed(2),
          ),

          salesToday: salesToday.length,

          visitsToday: salesToday.length,

          uniqueVisitorsToday:
            uniqueVisitorIds.size,

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
            redemptionsToday.length,
        },

        latestSales,

        activePromotions:
          activePromotions.slice(0, 8),

        upcomingEvents:
          upcomingEvents.slice(0, 8),

        recentRedemptions:
          redemptionsToday.slice(0, 8),
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