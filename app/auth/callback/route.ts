import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");

  const nextPath =
    requestUrl.searchParams.get("next") || "/account";

  if (code) {
    const supabase = await createClient();

    const { error } =
      await supabase.auth.exchangeCodeForSession(code);

    if (!error) {
      return NextResponse.redirect(
        new URL(nextPath, requestUrl.origin)
      );
    }
  }

  return NextResponse.redirect(
    new URL(
      "/login?error=Unable%20to%20confirm%20your%20account",
      requestUrl.origin
    )
  );
}