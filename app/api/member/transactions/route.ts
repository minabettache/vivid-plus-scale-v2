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

    const { data: member, error: memberError } = await supabase
      .from("members")
      .select("id, full_name, qr_code")
      .eq("qr_code", memberCode)
      .maybeSingle();

    if (memberError) {
      console.error("Member transaction lookup failed:", memberError);

      return NextResponse.json(
        { error: "Unable to retrieve member." },
        { status: 500 }
      );
    }

    if (!member) {
      return NextResponse.json(
        { error: "Member not found." },
        { status: 404 }
      );
    }

    const { data: transactions, error: transactionError } =
      await supabase
        .from("points_transactions")
        .select(
          `
            id,
            points_delta,
            balance_after,
            transaction_type,
            source_type,
            reason,
            created_at
          `
        )
        .eq("member_id", member.id)
        .order("created_at", { ascending: false })
        .limit(10);

    if (transactionError) {
      console.error(
        "Points transaction lookup failed:",
        transactionError
      );

      return NextResponse.json(
        { error: "Unable to retrieve transaction history." },
        { status: 500 }
      );
    }

    return NextResponse.json({
      member: {
        id: member.id,
        full_name: member.full_name,
        qr_code: member.qr_code,
      },
      transactions: transactions ?? [],
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

    console.error("Transaction history failed:", error);

    return NextResponse.json(
      { error: "Unable to retrieve transaction history." },
      { status: 500 }
    );
  }
}