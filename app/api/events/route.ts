import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

function getOrlandoDate() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/New_York',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

export async function GET() {
  try {
    const supabase = await createClient();
    const today = getOrlandoDate();

    const { data, error } = await supabase
      .from('events')
      .select(
        `
          id,
          title,
          description,
          event_date,
          start_time,
          end_time,
          flyer_url,
          tag,
          dj,
          admission
        `,
      )
      .eq('is_published', true)
      .gte('event_date', today)
      .order('event_date', { ascending: true })
      .order('start_time', { ascending: true });

    if (error) {
      console.error('Public events lookup failed:', error);

      return NextResponse.json(
        { error: 'Unable to load events.' },
        { status: 500 },
      );
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
    console.error('Public events route failed:', error);

    return NextResponse.json(
      { error: 'Unable to load events.' },
      { status: 500 },
    );
  }
}