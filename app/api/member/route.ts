import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { requireStaff } from "@/lib/auth/require-staff";

export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  try {
    await requireStaff();

    const memberCode = request.nextUrl.searchParams.get("qr")?.trim();

    if (!memberCode) {
      return NextResponse.json(
        { error: "Member code is required." },
        { status: 400 }
      );
    }

    const supabase = await createClient();

    const { data, error } = await supabase
      .from("members")
      .select(
        `
          id,
          full_name,
          membership_level,
          points,
          lifetime_points,
          total_visits,
          total_spent,
          last_visit_at,
          qr_code,
          is_active
        `
      )
      .eq("qr_code", memberCode)
      .maybeSingle();

    if (error) {
      console.error("Member lookup failed:", error);

      return NextResponse.json(
        { error: "Unable to retrieve member." },
        { status: 500 }
      );
    }

    if (!data) {
      return NextResponse.json(
        { error: "Member not found." },
        { status: 404 }
      );
    }

    if (!data.is_active) {
      return NextResponse.json(
        { error: "This member account is inactive." },
        { status: 403 }
      );
    }

    return NextResponse.json({
      member: data,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unexpected error";

    if (message === "UNAUTHENTICATED") {
      return NextResponse.json(
        { error: "Please sign in as staff." },
        { status: 401 }
      );
    }

    if (message === "STAFF_ACCESS_REQUIRED") {
      return NextResponse.json(
        { error: "An active staff account is required." },
        { status: 403 }
      );
    }

    console.error("Member lookup failed:", error);

    return NextResponse.json(
      { error: "Unable to retrieve member." },
      { status: 500 }
    );
  }
}