import { NextResponse } from 'next/server';
import { requireOwner } from '@/lib/auth/require-owner';
import { createClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';

type RouteContext = {
  params: Promise<{
    id: string;
  }>;
};

type UpdateEventRequest = {
  title?: unknown;
  description?: unknown;
  eventDate?: unknown;
  startTime?: unknown;
  endTime?: unknown;
  flyerUrl?: unknown;
  flyerPath?: unknown;
  tag?: unknown;
  dj?: unknown;
  admission?: unknown;
  isPublished?: unknown;
};

function cleanOptionalText(value: unknown, maxLength: number) {
  if (typeof value !== 'string') {
    return null;
  }

  const cleanValue = value.trim();

  if (!cleanValue) {
    return null;
  }

  return cleanValue.slice(0, maxLength);
}

function errorResponse(error: unknown) {
  const message =
    error instanceof Error ? error.message : 'Unexpected error';

  if (message === 'UNAUTHENTICATED') {
    return NextResponse.json(
      { error: 'Please sign in.' },
      { status: 401 },
    );
  }

  if (
    message === 'STAFF_ACCESS_REQUIRED' ||
    message === 'OWNER_ACCESS_REQUIRED'
  ) {
    return NextResponse.json(
      { error: 'Owner access is required.' },
      { status: 403 },
    );
  }

  console.error('Owner event update failed:', error);

  return NextResponse.json(
    { error: 'Unable to update the event.' },
    { status: 500 },
  );
}

export async function PATCH(
  request: Request,
  context: RouteContext,
) {
  try {
    await requireOwner();

    const { id } = await context.params;
    const body =
      (await request.json()) as UpdateEventRequest;

    const title =
      typeof body.title === 'string' ? body.title.trim() : '';

    const eventDate =
      typeof body.eventDate === 'string'
        ? body.eventDate.trim()
        : '';

    if (!title || title.length > 150) {
      return NextResponse.json(
        { error: 'A valid event title is required.' },
        { status: 400 },
      );
    }

    if (!/^\d{4}-\d{2}-\d{2}$/.test(eventDate)) {
      return NextResponse.json(
        { error: 'A valid event date is required.' },
        { status: 400 },
      );
    }

    const supabase = await createClient();

    const { data, error } = await supabase
      .from('events')
      .update({
        title,
        description: cleanOptionalText(body.description, 2000),
        event_date: eventDate,
        start_time: cleanOptionalText(body.startTime, 20),
        end_time: cleanOptionalText(body.endTime, 20),
        flyer_url: cleanOptionalText(body.flyerUrl, 1000),
        flyer_path: cleanOptionalText(body.flyerPath, 1000),
        tag:
          cleanOptionalText(body.tag, 80) ??
          'VIVID EVENT',
        dj: cleanOptionalText(body.dj, 150),
        admission: cleanOptionalText(body.admission, 150),
        is_published: body.isPublished === true,
      })
      .eq('id', id)
      .select('*')
      .single();

    if (error) {
      throw error;
    }

    return NextResponse.json({
      success: true,
      event: data,
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
    const supabase = await createClient();

    const { data: event } = await supabase
      .from('events')
      .select('flyer_path')
      .eq('id', id)
      .maybeSingle();

    const { error } = await supabase
      .from('events')
      .delete()
      .eq('id', id);

    if (error) {
      throw error;
    }

    if (event?.flyer_path) {
      await supabase.storage
        .from('event-flyers')
        .remove([event.flyer_path]);
    }

    return NextResponse.json({
      success: true,
    });
  } catch (error) {
    return errorResponse(error);
  }
}