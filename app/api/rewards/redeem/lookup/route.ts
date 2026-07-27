import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { requireStaff } from "@/lib/auth/require-staff";

export const runtime = "nodejs";

function cleanDatabaseMessage(message: string): string {
  const errorMap: Record<string, string> = {
    UNAUTHENTICATED: "Please sign in as staff.",
    STAFF_ACCESS_REQUIRED: "An active staff account is required.",
    REDEMPTION_CODE_REQUIRED: "A reward redemption code is required.",
    REDEMPTION_NOT_FOUND: "Reward redemption code not found.",
    MEMBER_NOT_FOUND: "The member connected to this reward was not found.",
    REWARD_NOT_FOUND: "The reward connected to this redemption was not found.",
  };

  return errorMap[message] ?? message.replaceAll("_", " ");
}

export async function GET(request: NextRequest) {
  try {
    await requireStaff();

    const redemptionCode = request.nextUrl.searchParams
      .get("code")
      ?.trim()
      .toUpperCase();

    if (!redemptionCode) {
      return NextResponse.json(
        { error: "Reward redemption code is required." },
        { status: 400 },
      );
    }

    if (!redemptionCode.startsWith("VVR-")) {
      return NextResponse.json(
        { error: "Enter a valid VIVID+ reward code beginning with VVR-." },
        { status: 400 },
      );
    }

    const supabase = await createClient();

    const { data, error } = await supabase.rpc(
      "get_reward_redemption_for_staff",
      {
        p_redemption_code: redemptionCode,
      },
    );

    if (error) {
      console.error("Reward redemption lookup failed:", error);

      const message = cleanDatabaseMessage(error.message);
      const notFound =
        error.code === "P0002" ||
        error.message.includes("REDEMPTION_NOT_FOUND");

      const forbidden =
        error.code === "42501" ||
        error.message.includes("UNAUTHENTICATED") ||
        error.message.includes("STAFF_ACCESS_REQUIRED");

      return NextResponse.json(
        { error: message },
        { status: notFound ? 404 : forbidden ? 403 : 400 },
      );
    }

    if (!data) {
      return NextResponse.json(
        { error: "Reward redemption code not found." },
        { status: 404 },
      );
    }

    return NextResponse.json({
      redemption: data,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unexpected error";

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

    console.error("Reward redemption lookup failed:", error);

    return NextResponse.json(
      { error: "Unable to retrieve reward redemption." },
      { status: 500 },
    );
  }
}