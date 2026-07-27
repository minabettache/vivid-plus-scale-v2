import { redirect } from 'next/navigation';

/**
 * VIVID+ opens directly into the Executive Command Center.
 * The API remains available at /api/v1/command-center for the UI and integrations.
 */
export default function HomePage() {
  redirect('/command-center');
}
