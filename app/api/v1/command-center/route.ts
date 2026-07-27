import { NextRequest, NextResponse } from 'next/server';
import { getCommandCenterSnapshot, normalizePeriod } from '@/lib/vivid-core/command-center/service';

const DEFAULT_ORGANIZATION_ID = 'vivid-technologies';
const DEFAULT_LOCATION_ID = 'vivid-lounge-orlando';

export async function GET(request: NextRequest) {
  const organizationId =
    request.headers.get('x-vivid-organization-id') ?? DEFAULT_ORGANIZATION_ID;
  const locationId =
    request.nextUrl.searchParams.get('locationId') ?? DEFAULT_LOCATION_ID;
  const period = normalizePeriod(request.nextUrl.searchParams.get('period'));

  const snapshot = await getCommandCenterSnapshot({
    organizationId,
    locationId,
    period
  });

  return NextResponse.json(
    { data: snapshot },
    {
      status: 200,
      headers: {
        'Cache-Control': 'private, max-age=30, stale-while-revalidate=60',
        'X-Vivid-Api-Version': '1'
      }
    }
  );
}
