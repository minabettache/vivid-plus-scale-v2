import { NextResponse } from 'next/server';
import { requireOwner } from '@/lib/auth/require-owner';
import { createClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

type PromotionRequest = {
  title?: unknown;
  description?: unknown;
  badge?: unknown;
  terms?: unknown;
  startAt?: unknown;
  endAt?: unknown;
  isPublished?: unknown;
};

function cleanText(
  value: unknown,
  maxLength: number,
) {
  if (typeof value !== 'string') {
    return null;
  }

  const cleaned = value.trim();

  if (!cleaned) {
    return null;
  }

  return cleaned.slice(0, maxLength);
}

function cleanDate(value: unknown) {
  if (
    typeof value !== 'string' ||
    !value.trim()
  ) {
    return null;
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date.toISOString();
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  if (
    typeof error === 'object' &&
    error !== null
  ) {
    const possibleError = error as {
      message?: unknown;
      details?: unknown;
      hint?: unknown;
      code?: unknown;
    };

    const parts = [
      typeof possibleError.message === 'string'
        ? possibleError.message
        : null,
      typeof possibleError.details === 'string'
        ? possibleError.details
        : null,
      typeof possibleError.hint === 'string'
        ? possibleError.hint
        : null,
      typeof possibleError.code === 'string'
        ? `Code: ${possibleError.code}`
        : null,
    ].filter(Boolean);

    if (parts.length > 0) {
      return parts.join(' | ');
    }

    try {
      return JSON.stringify(error);
    } catch {
      return 'Unexpected server error.';
    }
  }

  return String(error);
}

function ownerErrorResponse(error: unknown) {
  const message = getErrorMessage(error);

  if (message === 'UNAUTHENTICATED') {
    return NextResponse.json(
      {
        error: 'Please sign in.',
      },
      {
        status: 401,
      },
    );
  }

  if (
    message === 'STAFF_ACCESS_REQUIRED' ||
    message === 'OWNER_ACCESS_REQUIRED'
  ) {
    return NextResponse.json(
      {
        error: 'Owner access is required.',
      },
      {
        status: 403,
      },
    );
  }

  console.error(
    'Owner promotions error:',
    error,
  );

  return NextResponse.json(
    {
      error: message,
    },
    {
      status: 500,
    },
  );
}

export async function GET() {
  try {
    await requireOwner();

    const supabase = await createClient();

    const { data, error } = await supabase
      .from('promotions')
      .select('*')
      .order('created_at', {
        ascending: false,
      });

    if (error) {
      throw error;
    }

    return NextResponse.json(
      {
        promotions: data ?? [],
      },
      {
        headers: {
          'Cache-Control': 'no-store',
        },
      },
    );
  } catch (error) {
    return ownerErrorResponse(error);
  }
}

export async function POST(request: Request) {
  try {
    const { staff } = await requireOwner();

    const body =
      (await request.json()) as PromotionRequest;

    const title = cleanText(body.title, 180);

    if (!title) {
      return NextResponse.json(
        {
          error: 'Promotion title is required.',
        },
        {
          status: 400,
        },
      );
    }

    const startAt = cleanDate(body.startAt);
    const endAt = cleanDate(body.endAt);

    if (
      typeof body.startAt === 'string' &&
      body.startAt.trim() &&
      !startAt
    ) {
      return NextResponse.json(
        {
          error: 'The starting date is invalid.',
        },
        {
          status: 400,
        },
      );
    }

    if (
      typeof body.endAt === 'string' &&
      body.endAt.trim() &&
      !endAt
    ) {
      return NextResponse.json(
        {
          error: 'The ending date is invalid.',
        },
        {
          status: 400,
        },
      );
    }

    if (
      startAt &&
      endAt &&
      new Date(endAt) <= new Date(startAt)
    ) {
      return NextResponse.json(
        {
          error:
            'The ending date must be after the starting date.',
        },
        {
          status: 400,
        },
      );
    }

    const supabase = await createClient();

    const { data, error } = await supabase
      .from('promotions')
      .insert({
        title,
        description: cleanText(
          body.description,
          2000,
        ),
        badge:
          cleanText(body.badge, 100) ??
          'MEMBER SPECIAL',
        terms: cleanText(body.terms, 1000),
        start_at: startAt,
        end_at: endAt,
        is_published:
          body.isPublished === true,
        created_by: staff.id,
      })
      .select('*')
      .single();

    if (error) {
      console.error(
        'Supabase promotion insert error:',
        error,
      );

      throw error;
    }

    return NextResponse.json(
      {
        success: true,
        promotion: data,
      },
      {
        status: 201,
      },
    );
  } catch (error) {
    return ownerErrorResponse(error);
  }
}