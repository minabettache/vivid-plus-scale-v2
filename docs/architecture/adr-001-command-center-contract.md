# ADR-001: Executive Command Center Contract

## Status
Accepted

## Decision
The Executive Command Center reads from a versioned application API instead of importing database records directly into UI components.

Endpoint:

```text
GET /api/v1/command-center?period=today&locationId=vivid-lounge-orlando
```

Tenant context is supplied through the authenticated session. During the local foundation phase, the endpoint also accepts `x-vivid-organization-id` and uses a development fallback.

## Why

- Keeps the dashboard independent from the database schema.
- Gives web, mobile, and future partner clients one stable contract.
- Centralizes authorization, validation, caching, calculations, and AI insight assembly.
- Allows Supabase queries to replace seed data without rewriting the dashboard.
- Creates an explicit version boundary for future enterprise compatibility.

## Response responsibilities

The contract returns:

- Business health and factor scores.
- Executive KPI metrics.
- Prioritized actions.
- Explainable AI executive brief.
- Sales time-series data.
- Generation time, organization, location, and reporting period.

## Security requirements before production

1. Remove development tenant fallbacks.
2. Resolve organization and location from the authenticated membership.
3. Enforce `dashboard.read` authorization.
4. Record an audit event for privileged cross-location access.
5. Apply request tracing and rate limits.
6. Validate all query parameters at the API boundary.

## Next implementation step

Replace the seed service in `lib/vivid-core/command-center/service.ts` with organization-scoped Supabase queries while preserving the exported response type.
