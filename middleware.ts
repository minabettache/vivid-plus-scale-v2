import { createServerClient } from '@supabase/ssr';
import {
  NextResponse,
  type NextRequest,
} from 'next/server';

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key =
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !key) {
    return response;
  }

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => request.cookies.getAll(),

      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value),
        );

        response = NextResponse.next({ request });

        cookiesToSet.forEach(
          ({ name, value, options }) =>
            response.cookies.set(
              name,
              value,
              options,
            ),
        );
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const pathname = request.nextUrl.pathname;

  const protectedPath =
    pathname.startsWith('/staff/dashboard') ||
    pathname.startsWith('/scanner') ||
    pathname.startsWith('/owner');

  if (protectedPath && !user) {
    const loginUrl = request.nextUrl.clone();

    loginUrl.pathname = '/staff/login';
    loginUrl.searchParams.set('next', pathname);

    return NextResponse.redirect(loginUrl);
  }

  if (pathname === '/staff/login' && user) {
    const dashboardUrl = request.nextUrl.clone();

    dashboardUrl.pathname = '/staff/dashboard';

    return NextResponse.redirect(dashboardUrl);
  }

  return response;
}

export const config = {
  matcher: [
    '/staff/:path*',
    '/scanner/:path*',
    '/owner/:path*',
  ],
};