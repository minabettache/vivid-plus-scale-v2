import { NextResponse } from "next/server";
import { requireStaff } from "@/lib/auth/require-staff";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const { staff } = await requireStaff();

    return NextResponse.json(
      {
        staff: {
          id: staff.id,
          full_name: staff.full_name,
          role: staff.role,
          is_active: staff.is_active,
        },
      },
      {
        headers: {
          "Cache-Control": "no-store",
        },
      }
    );
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : "Unexpected error";

    if (message === "UNAUTHENTICATED") {
      return NextResponse.json(
        { error: "Please sign in as staff." },
        { status: 401 }
      );
    }

    if (message === "STAFF_ACCESS_REQUIRED") {
      return NextResponse.json(
        {
          error:
            "This account does not have active staff access.",
        },
        { status: 403 }
      );
    }

    console.error("Staff account lookup failed:", error);

    return NextResponse.json(
      { error: "Unable to verify staff account." },
      { status: 500 }
    );
  }
}