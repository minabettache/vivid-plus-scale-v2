import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { requireStaff } from "@/lib/auth/require-staff";

export const runtime = "nodejs";

type RecordSaleRequest = {
  memberCode?: unknown;
  amountPaid?: unknown;
  paymentMethod?: unknown;
  note?: unknown;
  idempotencyKey?: unknown;
};

export async function POST(request: Request) {
  try {
    const { staff } = await requireStaff();
    const body = (await request.json()) as RecordSaleRequest;

    const memberCode =
      typeof body.memberCode === "string"
        ? body.memberCode.trim()
        : "";

    const amountPaid =
      typeof body.amountPaid === "number"
        ? body.amountPaid
        : Number(body.amountPaid);

    const paymentMethod =
      typeof body.paymentMethod === "string"
        ? body.paymentMethod.trim().toLowerCase()
        : "";

    const note =
      typeof body.note === "string"
        ? body.note.trim()
        : "";

    const idempotencyKey =
      typeof body.idempotencyKey === "string" &&
      body.idempotencyKey.trim()
        ? body.idempotencyKey.trim()
        : crypto.randomUUID();

    if (!memberCode) {
      return NextResponse.json(
        { error: "Member code is required." },
        { status: 400 },
      );
    }

    if (
      !Number.isFinite(amountPaid) ||
      amountPaid < 0.01 ||
      amountPaid > 100000
    ) {
      return NextResponse.json(
        {
          error:
            "Amount paid must be between $0.01 and $100,000.",
        },
        { status: 400 },
      );
    }

    if (
      paymentMethod !== "cash" &&
      paymentMethod !== "card"
    ) {
      return NextResponse.json(
        { error: "Payment method must be cash or card." },
        { status: 400 },
      );
    }

    if (note.length > 250) {
      return NextResponse.json(
        { error: "Note cannot exceed 250 characters." },
        { status: 400 },
      );
    }

    const supabase = await createClient();

    const { data, error } = await supabase.rpc(
      "record_member_sale",
      {
        p_member_code: memberCode,
        p_amount_paid: Number(amountPaid.toFixed(2)),
        p_payment_method: paymentMethod,
        p_note: note || null,
        p_idempotency_key: idempotencyKey,
        p_metadata: {
          staff_role: staff.role,
          request_source: "staff_scanner",
        },
      },
    );

    if (error) {
      const notFound =
        error.code === "P0002" ||
        /not found/i.test(error.message);

      const forbidden = error.code === "42501";

      return NextResponse.json(
        { error: error.message },
        {
          status: notFound
            ? 404
            : forbidden
              ? 403
              : 400,
        },
      );
    }

    const result = Array.isArray(data) ? data[0] : data;

    return NextResponse.json({
      success: true,
      result,
      idempotencyKey,
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

    console.error("Record member sale failed:", error);

    return NextResponse.json(
      { error: "Unable to record sale." },
      { status: 500 },
    );
  }
}
