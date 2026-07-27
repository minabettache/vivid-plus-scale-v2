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

    const { data: member, error: memberError } = await supabase
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
        is_active,
        created_at
      `
      )
      .eq("user_id", user.id)
      .maybeSingle();

    if (memberError) {
      console.error(memberError);

      return NextResponse.json(
        { error: "Unable to load your membership." },
        { status: 500 }
      );
    }

    if (!member) {
      return NextResponse.json(
        {
          error: "Your login is not linked to a VIVID+ membership yet.",
          code: "MEMBER_NOT_LINKED",
        },
        { status: 404 }
      );
    }

    if (!member.is_active) {
      return NextResponse.json(
        {
          error: "Your VIVID+ membership is inactive.",
          code: "MEMBER_INACTIVE",
        },
        { status: 403 }
      );
    }

    return NextResponse.json(
      { member },
      {
        status: 200,
        headers: {
          "Cache-Control": "no-store",
        },
      }
    );
  } catch (error) {
    console.error(error);

    return NextResponse.json(
      { error: "Unexpected server error." },
      { status: 500 }
    );
  }
}