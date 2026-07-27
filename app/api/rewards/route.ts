import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function GET() {
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

    const { data: rewards, error } = await supabase
      .from("rewards")
      .select(
        `
        id,
        name,
        description,
        points_required,
        estimated_business_cost,
        minimum_spend,
        age_restricted,
        minimum_age,
        is_active,
        created_at
        `
      )
      .eq("is_active", true)
      .order("points_required", {
        ascending: true,
      });

    if (error) {
      console.error("Rewards lookup failed:", error);

      return NextResponse.json(
        { error: "Unable to load rewards." },
        { status: 500 }
      );
    }

    return NextResponse.json(
      {
        rewards: rewards ?? [],
      },
      {
        headers: {
          "Cache-Control": "no-store",
        },
      }
    );
  } catch (error) {
    console.error("Rewards route failed:", error);

    return NextResponse.json(
      { error: "Unexpected server error." },
      { status: 500 }
    );
  }
}