import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type RedeemRequest = {
  rewardId?: unknown;
};

export async function POST(request: Request) {
  try {
    const supabase = await createClient();

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return NextResponse.json(
        { error: "You must be logged in." },
        { status: 401 }
      );
    }

    const body = (await request.json()) as RedeemRequest;
    const rewardId = Number(body.rewardId);

    if (!Number.isSafeInteger(rewardId) || rewardId < 1) {
      return NextResponse.json(
        { error: "A valid reward is required." },
        { status: 400 }
      );
    }

    const { data, error } = await supabase.rpc(
      "create_reward_redemption",
      {
        p_reward_id: rewardId,
      }
    );

    if (error) {
      console.error("Create redemption failed:", error);

      const message = error.message || "";

      if (/INSUFFICIENT_POINTS/i.test(message)) {
        return NextResponse.json(
          { error: "You do not have enough points for this reward." },
          { status: 400 }
        );
      }

      if (/REWARD_NOT_FOUND/i.test(message)) {
        return NextResponse.json(
          { error: "This reward is unavailable." },
          { status: 404 }
        );
      }

      if (/ACTIVE_MEMBER_NOT_FOUND/i.test(message)) {
        return NextResponse.json(
          { error: "An active member account was not found." },
          { status: 404 }
        );
      }

      return NextResponse.json(
        { error: "Unable to create redemption." },
        { status: 400 }
      );
    }

    return NextResponse.json(
      {
        success: true,
        redemption: data,
      },
      {
        headers: {
          "Cache-Control": "no-store",
        },
      }
    );
  } catch (error) {
    console.error("Redemption route failed:", error);

    return NextResponse.json(
      { error: "Unexpected server error." },
      { status: 500 }
    );
  }
}