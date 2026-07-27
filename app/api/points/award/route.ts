import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { requireStaff } from "@/lib/auth/require-staff";

export const runtime = "nodejs";

type AwardRequest = {
  memberCode?: unknown;
  points?: unknown;
  reason?: unknown;
  idempotencyKey?: unknown;
};

export async function POST(request: Request) {
  try {
    const { staff } = await requireStaff();
    const body = (await request.json()) as AwardRequest;

    const memberCode = typeof body.memberCode === "string" ? body.memberCode.trim() : "";
    const reason = typeof body.reason === "string" ? body.reason.trim() : "";
    const points = typeof body.points === "number" ? body.points : Number(body.points);
    const idempotencyKey =
      typeof body.idempotencyKey === "string" && body.idempotencyKey.trim()
        ? body.idempotencyKey.trim()
        : crypto.randomUUID();

    if (!memberCode) {
      return NextResponse.json({ error: "Member code is required." }, { status: 400 });
    }
    if (!Number.isSafeInteger(points) || points < 1 || points > 100000) {
      return NextResponse.json({ error: "Points must be a whole number between 1 and 100000." }, { status: 400 });
    }
    if (!reason || reason.length > 250) {
      return NextResponse.json({ error: "A reason between 1 and 250 characters is required." }, { status: 400 });
    }

    const supabase = await createClient();
    const { data, error } = await supabase.rpc("award_member_points", {
      p_member_code: memberCode,
      p_points: points,
      p_reason: reason,
      p_idempotency_key: idempotencyKey,
      p_metadata: {
        staff_role: staff.role,
        request_source: "staff_scanner",
      },
    });

    if (error) {
      const notFound = error.code === "P0002" || /not found/i.test(error.message);
      const forbidden = error.code === "42501";
      return NextResponse.json(
        { error: error.message },
        { status: notFound ? 404 : forbidden ? 403 : 400 },
      );
    }

    const result = Array.isArray(data) ? data[0] : data;
    return NextResponse.json({ success: true, result, idempotencyKey });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error";
    if (message === "UNAUTHENTICATED") {
      return NextResponse.json({ error: "Please sign in as staff." }, { status: 401 });
    }
    if (message === "STAFF_ACCESS_REQUIRED") {
      return NextResponse.json({ error: "An active staff account is required." }, { status: 403 });
    }
    console.error("Award points failed:", error);
    return NextResponse.json({ error: "Unable to award points." }, { status: 500 });
  }
}
