import { NextResponse } from 'next/server';
import { requireOwner } from '@/lib/auth/require-owner';
import { createClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

type EventRequest = {
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

function ownerErrorResponse(error: unknown) {
  const message =
    error instanceof Error ? error.message : 'Unexpected error';

  if (message === 'UNAUTHENTICATED') {
    return NextResponse.json(
      { error: 'Please sign in.' },
      { status: 401 },
    );
  }

  if (message === 'STAFF_ACCESS_REQUIRED') {
    return NextResponse.json(
      { error: 'An active staff account is required.' },
      { status: 403 },
    );
  }

  if (message === 'OWNER_ACCESS_REQUIRED') {
    return NextResponse.json(
      { error: 'Owner access is required.' },
      { status: 403 },
    );
  }

  console.error('Owner events error:', error);

  return NextResponse.json(
    { error: 'Unable to process the event request.' },
    { status: 500 },
  );
}

export async function GET() {
  try {
    await requireOwner();

    const supabase = await createClient();

    const { data, error } = await supabase
      .from('events')
      .select('*')
      .order('event_date', { ascending: false })
      .order('created_at', { ascending: false });

    if (error) {
      throw error;
    }

    return NextResponse.json(
      {
        events: data ?? [],
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
    const body = (await request.json()) as EventRequest;

    const title =
      typeof body.title === 'string' ? body.title.trim() : '';

    const eventDate =
      typeof body.eventDate === 'string'
        ? body.eventDate.trim()
        : '';

    if (!title || title.length > 150) {
      return NextResponse.json(
        {
          error:
            'Event title is required and must be under 150 characters.',
        },
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
      .insert({
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
        created_by: staff.id,
      })
      .select('*')
      .single();

    if (error) {
      throw error;
    }

    return NextResponse.json(
      {
        success: true,
        event: data,
      },
      { status: 201 },
    );
  } catch (error) {
    return ownerErrorResponse(error);
  }
}