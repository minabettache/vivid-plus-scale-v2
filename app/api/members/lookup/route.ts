import { NextResponse } from "next/server";
import { requireStaff } from "@/lib/auth/require-staff";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

type LookupRequest = {
  memberCode?: unknown;
};

export async function POST(request: Request) {
  try {
    await requireStaff();

    const body = (await request.json()) as LookupRequest;

    const memberCode =
      typeof body.memberCode === "string"
        ? body.memberCode.trim()
        : "";

    if (!memberCode) {
      return NextResponse.json(
        { error: "Member code is required." },
        { status: 400 },
      );
    }

    const supabase = await createClient();

    const { data: member, error } = await supabase
      .from("members")
      .select(`
        id,
        full_name,
        phone,
        email,
        membership_level,
        points,
        birthday,
        qr_code,
        is_active,
        lifetime_points,
        total_visits,
        total_spent,
        last_visit_at,
        created_at
      `)
      .eq("qr_code", memberCode)
      .maybeSingle();

    if (error) {
      console.error("Member lookup failed:", error);

      return NextResponse.json(
        { error: "Unable to look up member." },
        { status: 500 },
      );
    }

    if (!member) {
      return NextResponse.json(
        { error: "Member not found." },
        { status: 404 },
      );
    }

    if (!member.is_active) {
      return NextResponse.json(
        { error: "This member account is inactive." },
        { status: 403 },
      );
    }

    return NextResponse.json({
      success: true,
      member: {
        ...member,
        points: Number(member.points ?? 0),
        lifetime_points: Number(member.lifetime_points ?? 0),
        total_visits: Number(member.total_visits ?? 0),
        total_spent: Number(member.total_spent ?? 0),
      },
    });
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : "Unexpected error";

    if (message === "UNAUTHENTICATED") {
      return NextResponse.json(
        { error: "Please sign in as staff." },
        { status: 401 },
      );
    }

    if (message === "STAFF_ACCESS_REQUIRED") {
      return NextResponse.json(
        { error: "An active staff account is required." },
        { status: 403 },
      );
    }

    console.error("Member lookup failed:", error);

    return NextResponse.json(
      { error: "Unable to look up member." },
      { status: 500 },
    );
  }
}
