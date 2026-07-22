'use client';

import { ArrowRight, CheckCircle2, ShieldCheck, Sparkles } from 'lucide-react';
import { useState } from 'react';
import { interests } from '@/lib/data';
import { createMemberId } from '@/lib/member';
import type { Interest, Member } from '@/lib/types';
import { BrandLogo } from './BrandLogo';

export function Onboarding({ onJoin }: { onJoin: (member: Member) => void }) {
  const [showForm, setShowForm] = useState(false);

  const [form, setForm] = useState({
    name: '',
    phone: '',
    birthday: '',
    interests: [] as Interest[],
  });

  function toggleInterest(value: Interest) {
    setForm((current) => ({
      ...current,
      interests: current.interests.includes(value)
        ? current.interests.filter((item) => item !== value)
        : [...current.interests, value],
    }));
  }

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const member: Member = {
      memberId: createMemberId(form.name, form.phone),
      name: form.name,
      phone: form.phone,
      birthday: form.birthday,
      interests: form.interests,
      joinedAt: new Date().toISOString(),
      points: 100,
      membershipLevel: 'Gold',
    };

    onJoin(member);
  }

  return (
    <main className="welcome-shell">
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />

      <section className="welcome-card">
        <div className="welcome-topline">
          <BrandLogo />
          <span>
            <Sparkles size={14} /> Orlando&apos;s premium rewards experience
          </span>
        </div>

        {!showForm ? (
          <div className="welcome-intro">
            <p className="eyebrow">VIVID SMOKE SHOP &amp; LOUNGE</p>

            <h1>
              Your Vivid experience, <em>upgraded.</em>
            </h1>

            <p className="welcome-copy">
              Unlock points, priority event access, member-only offers,
              birthday rewards, and a digital VIP card built for your nights
              at Vivid.
            </p>

            <div className="benefit-row">
              <span>
                <CheckCircle2 size={16} /> 100 welcome points
              </span>

              <span>
                <CheckCircle2 size={16} /> Member-only offers
              </span>

              <span>
                <CheckCircle2 size={16} /> VIP event access
              </span>
            </div>

            <button
              className="primary large"
              onClick={() => setShowForm(true)}
            >
              Become a member <ArrowRight size={18} />
            </button>

            <p className="fine-print">
              <ShieldCheck size={14} /> Free to join. Age verification may be
              required for certain offers.
            </p>
          </div>
        ) : (
          <form className="join-form" onSubmit={submit}>
            <div className="form-heading">
              <div>
                <p className="eyebrow">CREATE YOUR MEMBERSHIP</p>
                <h2>Join VIVID+</h2>
              </div>

              <button
                type="button"
                className="text-button"
                onClick={() => setShowForm(false)}
              >
                Back
              </button>
            </div>

            <label>
              Full name
              <input
                required
                value={form.name}
                onChange={(e) =>
                  setForm({ ...form, name: e.target.value })
                }
                placeholder="Ali Abide"
              />
            </label>

            <label>
              Mobile number
              <input
                required
                type="tel"
                value={form.phone}
                onChange={(e) =>
                  setForm({ ...form, phone: e.target.value })
                }
                placeholder="(407) 555-0199"
              />
            </label>

            <label>
              Birthday
              <input
                required
                type="date"
                value={form.birthday}
                onChange={(e) =>
                  setForm({ ...form, birthday: e.target.value })
                }
              />
            </label>

            <fieldset>
              <legend>What do you enjoy at Vivid?</legend>

              <div className="chips">
                {interests.map((interest) => (
                  <button
                    key={interest}
                    type="button"
                    className={
                      form.interests.includes(interest)
                        ? 'chip active'
                        : 'chip'
                    }
                    onClick={() => toggleInterest(interest)}
                  >
                    {interest}
                  </button>
                ))}
              </div>
            </fieldset>

            <label className="consent">
              <input required type="checkbox" />
              I agree to receive VIVID+ membership updates and promotional
              messages.
            </label>

            <button className="primary large" type="submit">
              Join free — get 100 points <ArrowRight size={18} />
            </button>
          </form>
        )}
      </section>
    </main>
  );
}