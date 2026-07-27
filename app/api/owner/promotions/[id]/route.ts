import { NextResponse } from 'next/server';
import { requireOwner } from '@/lib/auth/require-owner';
import { createClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';

type RouteContext = {
  params: Promise<{
    id: string;
  }>;
};

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

function errorResponse(error: unknown) {
  const message =
    error instanceof Error
      ? error.message
      : 'Unexpected error';

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
    'Owner promotion update failed:',
    error,
  );

  return NextResponse.json(
    {
      error: 'Unable to update the promotion.',
    },
    {
      status: 500,
    },
  );
}

export async function PATCH(
  request: Request,
  context: RouteContext,
) {
  try {
    await requireOwner();

    const { id } = await context.params;
    const numericId = Number(id);

    if (
      !Number.isSafeInteger(numericId) ||
      numericId < 1
    ) {
      return NextResponse.json(
        {
          error: 'Invalid promotion ID.',
        },
        {
          status: 400,
        },
      );
    }

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
      .update({
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
      })
      .eq('id', numericId)
      .select('*')
      .single();

    if (error) {
      throw error;
    }

    return NextResponse.json({
      success: true,
      promotion: data,
    });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function DELETE(
  _request: Request,
  context: RouteContext,
) {
  try {
    await requireOwner();

    const { id } = await context.params;
    const numericId = Number(id);

    if (
      !Number.isSafeInteger(numericId) ||
      numericId < 1
    ) {
      return NextResponse.json(
        {
          error: 'Invalid promotion ID.',
        },
        {
          status: 400,
        },
      );
    }

    const supabase = await createClient();

    const { error } = await supabase
      .from('promotions')
      .delete()
      .eq('id', numericId);

    if (error) {
      throw error;
    }

    return NextResponse.json({
      success: true,
    });
  } catch (error) {
    return errorResponse(error);
  }
}