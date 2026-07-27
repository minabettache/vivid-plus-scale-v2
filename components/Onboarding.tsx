'use client';

import {
  ArrowRight,
  CheckCircle2,
  Loader2,
  LogIn,
  ShieldCheck,
  Sparkles
} from 'lucide-react';
import { useState } from 'react';
import { interests } from '@/lib/data';
import {
  signInMember,
  signUpMember
} from '@/lib/member';
import type { Interest, Member } from '@/lib/types';
import { BrandLogo } from './BrandLogo';

type AuthMode = 'welcome' | 'signup' | 'signin';

type SignUpForm = {
  fullName: string;
  phone: string;
  email: string;
  password: string;
  birthday: string;
  interests: Interest[];
  consent: boolean;
};

type SignInForm = {
  email: string;
  password: string;
};

export function Onboarding({
  onAuthenticated
}: {
  onAuthenticated: (member: Member) => void;
}) {
  const [mode, setMode] = useState<AuthMode>('welcome');

  const [signUpForm, setSignUpForm] = useState<SignUpForm>({
    fullName: '',
    phone: '',
    email: '',
    password: '',
    birthday: '',
    interests: [],
    consent: false
  });

  const [signInForm, setSignInForm] = useState<SignInForm>({
    email: '',
    password: ''
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [confirmationMessage, setConfirmationMessage] =
    useState('');

  function changeMode(nextMode: AuthMode) {
    setError('');
    setConfirmationMessage('');
    setMode(nextMode);
  }

  function toggleInterest(value: Interest) {
    setSignUpForm((current) => ({
      ...current,
      interests: current.interests.includes(value)
        ? current.interests.filter((item) => item !== value)
        : [...current.interests, value]
    }));
  }

  async function submitSignUp(
    event: React.FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();
    setLoading(true);
    setError('');
    setConfirmationMessage('');

    try {
      const result = await signUpMember({
        fullName: signUpForm.fullName,
        phone: signUpForm.phone,
        email: signUpForm.email,
        password: signUpForm.password,
        birthday: signUpForm.birthday,
        interests: signUpForm.interests
      });

      if (result.requiresEmailConfirmation) {
        setConfirmationMessage(
          'Your VIVID+ account was created. Check your email and confirm your account, then return here to sign in.'
        );

        setSignInForm({
          email: signUpForm.email,
          password: signUpForm.password
        });

        setMode('signin');
        return;
      }

      if (!result.member) {
        throw new Error(
          'Your account was created, but the member profile could not be loaded.'
        );
      }

      onAuthenticated(result.member);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : 'Unable to create your membership.'
      );
    } finally {
      setLoading(false);
    }
  }

  async function submitSignIn(
    event: React.FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();
    setLoading(true);
    setError('');

    try {
      const member = await signInMember(signInForm);
      onAuthenticated(member);
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : 'Unable to sign in.'
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="welcome-shell">
      <div className="ambient ambient-one" />
      <div className="ambient ambient-two" />

      <section className="welcome-card">
        <div className="welcome-topline">
          <BrandLogo />

          <span>
            <Sparkles size={14} />
            Orlando&apos;s premium rewards experience
          </span>
        </div>

        {mode === 'welcome' && (
          <div className="welcome-intro">
            <p className="eyebrow">
              VIVID SMOKE SHOP &amp; LOUNGE
            </p>

            <h1>
              Your Vivid experience, <em>upgraded.</em>
            </h1>

            <p className="welcome-copy">
              Unlock points, priority event access,
              member-only offers, birthday rewards, and a
              digital VIP card built for your nights at Vivid.
            </p>

            <div className="benefit-row">
              <span>
                <CheckCircle2 size={16} />
                100 welcome points
              </span>

              <span>
                <CheckCircle2 size={16} />
                Member-only offers
              </span>

              <span>
                <CheckCircle2 size={16} />
                VIP event access
              </span>
            </div>

            <button
              type="button"
              className="primary large"
              onClick={() => changeMode('signup')}
            >
              Become a member
              <ArrowRight size={18} />
            </button>

            <button
              type="button"
              className="text-button"
              onClick={() => changeMode('signin')}
            >
              Already a member? Sign in
            </button>

            <p className="fine-print">
              <ShieldCheck size={14} />
              Free to join. Age verification may be required
              for certain offers.
            </p>
          </div>
        )}

        {mode === 'signup' && (
          <form
            className="join-form"
            onSubmit={submitSignUp}
          >
            <div className="form-heading">
              <div>
                <p className="eyebrow">
                  CREATE YOUR MEMBERSHIP
                </p>
                <h2>Join VIVID+</h2>
              </div>

              <button
                type="button"
                className="text-button"
                onClick={() => changeMode('welcome')}
              >
                Back
              </button>
            </div>

            {error && (
              <div className="auth-message error">
                {error}
              </div>
            )}

            <label>
              Full name
              <input
                required
                autoComplete="name"
                value={signUpForm.fullName}
                onChange={(event) =>
                  setSignUpForm({
                    ...signUpForm,
                    fullName: event.target.value
                  })
                }
                placeholder="Ali Abide"
              />
            </label>

            <label>
              Mobile number
              <input
                required
                type="tel"
                autoComplete="tel"
                value={signUpForm.phone}
                onChange={(event) =>
                  setSignUpForm({
                    ...signUpForm,
                    phone: event.target.value
                  })
                }
                placeholder="(407) 555-0199"
              />
            </label>

            <label>
              Email address
              <input
                required
                type="email"
                autoComplete="email"
                value={signUpForm.email}
                onChange={(event) =>
                  setSignUpForm({
                    ...signUpForm,
                    email: event.target.value
                  })
                }
                placeholder="you@example.com"
              />
            </label>

            <label>
              Password
              <input
                required
                minLength={8}
                type="password"
                autoComplete="new-password"
                value={signUpForm.password}
                onChange={(event) =>
                  setSignUpForm({
                    ...signUpForm,
                    password: event.target.value
                  })
                }
                placeholder="Minimum 8 characters"
              />
            </label>

            <label>
              Birthday
              <input
                required
                type="date"
                value={signUpForm.birthday}
                onChange={(event) =>
                  setSignUpForm({
                    ...signUpForm,
                    birthday: event.target.value
                  })
                }
              />
            </label>

            <fieldset>
              <legend>
                What do you enjoy at Vivid?
              </legend>

              <div className="chips">
                {interests.map((interest) => (
                  <button
                    type="button"
                    key={interest}
                    className={
                      signUpForm.interests.includes(interest)
                        ? 'chip active'
                        : 'chip'
                    }
                    onClick={() =>
                      toggleInterest(interest)
                    }
                  >
                    {interest}
                  </button>
                ))}
              </div>
            </fieldset>

            <label className="consent">
              <input
                required
                type="checkbox"
                checked={signUpForm.consent}
                onChange={(event) =>
                  setSignUpForm({
                    ...signUpForm,
                    consent: event.target.checked
                  })
                }
              />

              I agree to receive VIVID+ membership updates
              and promotional messages. Message and data
              rates may apply.
            </label>

            <button
              className="primary large"
              type="submit"
              disabled={loading}
            >
              {loading ? (
                <>
                  <Loader2
                    size={18}
                    className="spin"
                  />
                  Creating membership...
                </>
              ) : (
                <>
                  Join free — get 100 points
                  <ArrowRight size={18} />
                </>
              )}
            </button>

            <button
              type="button"
              className="text-button"
              onClick={() => changeMode('signin')}
            >
              Already registered? Sign in
            </button>
          </form>
        )}

        {mode === 'signin' && (
          <form
            className="join-form"
            onSubmit={submitSignIn}
          >
            <div className="form-heading">
              <div>
                <p className="eyebrow">
                  MEMBER ACCESS
                </p>
                <h2>Welcome back</h2>
              </div>

              <button
                type="button"
                className="text-button"
                onClick={() => changeMode('welcome')}
              >
                Back
              </button>
            </div>

            {confirmationMessage && (
              <div className="auth-message success">
                {confirmationMessage}
              </div>
            )}

            {error && (
              <div className="auth-message error">
                {error}
              </div>
            )}

            <label>
              Email address
              <input
                required
                type="email"
                autoComplete="email"
                value={signInForm.email}
                onChange={(event) =>
                  setSignInForm({
                    ...signInForm,
                    email: event.target.value
                  })
                }
                placeholder="you@example.com"
              />
            </label>

            <label>
              Password
              <input
                required
                type="password"
                autoComplete="current-password"
                value={signInForm.password}
                onChange={(event) =>
                  setSignInForm({
                    ...signInForm,
                    password: event.target.value
                  })
                }
                placeholder="Your password"
              />
            </label>

            <button
              className="primary large"
              type="submit"
              disabled={loading}
            >
              {loading ? (
                <>
                  <Loader2
                    size={18}
                    className="spin"
                  />
                  Signing in...
                </>
              ) : (
                <>
                  <LogIn size={18} />
                  Sign in to VIVID+
                </>
              )}
            </button>

            <button
              type="button"
              className="text-button"
              onClick={() => changeMode('signup')}
            >
              New to VIVID+? Create an account
            </button>

            <p className="fine-print">
              <ShieldCheck size={14} />
              Your membership information is protected by
              secure authentication.
            </p>
          </form>
        )}
      </section>
    </main>
  );
}
