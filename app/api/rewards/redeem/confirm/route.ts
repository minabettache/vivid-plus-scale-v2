import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { requireStaff } from "@/lib/auth/require-staff";

export const runtime = "nodejs";

type ConfirmRewardRequest = {
  redemptionCode?: unknown;
  idVerified?: unknown;
};

function cleanDatabaseMessage(message: string): string {
  const errorMap: Record<string, string> = {
    UNAUTHENTICATED: "Please sign in as staff.",
    STAFF_ACCESS_REQUIRED: "An active staff account is required.",
    REDEMPTION_CODE_REQUIRED: "A reward redemption code is required.",
    REDEMPTION_NOT_FOUND: "Reward redemption code not found.",
    REDEMPTION_ALREADY_USED: "This reward has already been redeemed.",
    REDEMPTION_EXPIRED: "This reward redemption code has expired.",
    REDEMPTION_CANCELLED: "This reward redemption was cancelled.",
    REDEMPTION_NOT_PENDING: "This reward is not available for confirmation.",
    MEMBER_NOT_FOUND: "The member connected to this reward was not found.",
    MEMBER_INACTIVE: "This member account is inactive.",
    REWARD_NOT_FOUND: "The reward connected to this redemption was not found.",
    ID_VERIFICATION_REQUIRED:
      "Verify the member's physical ID before confirming this reward.",
    INSUFFICIENT_POINTS:
      "The member no longer has enough points for this reward.",
  };

  return errorMap[message] ?? message.replaceAll("_", " ");
}

export async function POST(request: Request) {
  try {
    await requireStaff();

    const body = (await request.json()) as ConfirmRewardRequest;

    const redemptionCode =
      typeof body.redemptionCode === "string"
        ? body.redemptionCode.trim().toUpperCase()
        : "";

    const idVerified = body.idVerified === true;

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
      "confirm_reward_redemption",
      {
        p_redemption_code: redemptionCode,
        p_id_verified: idVerified,
      },
    );

    if (error) {
      console.error("Reward confirmation failed:", error);

      const message = cleanDatabaseMessage(error.message);

      const notFound =
        error.code === "P0002" ||
        error.message.includes("REDEMPTION_NOT_FOUND") ||
        error.message.includes("MEMBER_NOT_FOUND") ||
        error.message.includes("REWARD_NOT_FOUND");

      const forbidden =
        error.code === "42501" ||
        error.message.includes("UNAUTHENTICATED") ||
        error.message.includes("STAFF_ACCESS_REQUIRED");

      const conflict =
        error.message.includes("REDEMPTION_ALREADY_USED") ||
        error.message.includes("REDEMPTION_EXPIRED") ||
        error.message.includes("REDEMPTION_CANCELLED") ||
        error.message.includes("REDEMPTION_NOT_PENDING") ||
        error.message.includes("INSUFFICIENT_POINTS");

      return NextResponse.json(
        { error: message },
        {
          status: notFound
            ? 404
            : forbidden
              ? 403
              : conflict
                ? 409
                : 400,
        },
      );
    }

    if (!data) {
      return NextResponse.json(
        { error: "Reward confirmation did not return a result." },
        { status: 500 },
      );
    }

    return NextResponse.json({
      success: true,
      result: data,
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

    console.error("Reward confirmation failed:", error);

    return NextResponse.json(
      { error: "Unable to confirm reward redemption." },
      { status: 500 },
    );
  }
}