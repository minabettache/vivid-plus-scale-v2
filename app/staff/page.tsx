"use client";

import { createBrowserClient } from "@supabase/ssr";
import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";

export default function StaffLoginPage() {
  const router = useRouter();

  const [email, setEmail] = useState(
    "info@vividhookahloungeorlando.com"
  );
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState(
    "Sign in with an active VIVID+ staff account."
  );
  const [loading, setLoading] = useState(false);
  const [isError, setIsError] = useState(false);

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (loading) {
      return;
    }

    const cleanEmail = email.trim();

    if (!cleanEmail || !password) {
      setMessage("Enter your staff email and password.");
      setIsError(true);
      return;
    }

    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key =
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

    if (!url || !key) {
      setMessage("Supabase environment variables are missing.");
      setIsError(true);
      return;
    }

    setLoading(true);
    setIsError(false);
    setMessage("Signing in securely...");

    try {
      const supabase = createBrowserClient(url, key);

      const { error } =
        await supabase.auth.signInWithPassword({
          email: cleanEmail,
          password,
        });

      if (error) {
        throw new Error(error.message);
      }

      const response = await fetch("/api/staff/account", {
        method: "GET",
        cache: "no-store",
        credentials: "include",
      });

      const payload = (await response.json()) as {
        staff?: {
          full_name: string;
          role: string;
        };
        error?: string;
      };

      if (!response.ok || !payload.staff) {
        await supabase.auth.signOut();

        throw new Error(
          payload.error ||
            "This account does not have active staff access."
        );
      }

      setMessage(
        `Welcome ${payload.staff.full_name}. Opening scanner...`
      );

      router.replace("/scanner");
      router.refresh();
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : "Unable to sign in."
      );
      setIsError(true);
    } finally {
      setLoading(false);
    }
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: 20,
        background: "#090909",
        color: "#ffffff",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: 460,
          padding: 28,
          border: "1px solid #353535",
          borderRadius: 24,
          background:
            "linear-gradient(145deg, #191919 0%, #101010 100%)",
          boxShadow: "0 24px 80px rgba(0,0,0,0.55)",
        }}
      >
        <p
          style={{
            margin: 0,
            color: "#f5a623",
            fontSize: 13,
            fontWeight: 900,
            letterSpacing: "0.1em",
          }}
        >
          VIVID+ STAFF ACCESS
        </p>

        <h1
          style={{
            margin: "14px 0 0",
            fontSize: "clamp(2rem, 6vw, 3rem)",
          }}
        >
          Staff sign in
        </h1>

        <p
          style={{
            marginTop: 12,
            color: "#aaaaaa",
            lineHeight: 1.6,
          }}
        >
          Sign in to scan members, award points, and confirm
          rewards.
        </p>

        <div
          role={isError ? "alert" : "status"}
          style={{
            marginTop: 20,
            padding: 14,
            border: `1px solid ${
              isError ? "#d14b4b" : "#3a3a3a"
            }`,
            borderRadius: 14,
            background: isError ? "#3b1515" : "#1d1d1d",
            color: "#ffffff",
            lineHeight: 1.5,
          }}
        >
          {message}
        </div>

        <form onSubmit={handleLogin}>
          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 22,
            }}
          >
            <span>Staff email</span>

            <input
              type="email"
              value={email}
              onChange={(event) =>
                setEmail(event.target.value)
              }
              autoComplete="email"
              disabled={loading}
              style={{
                width: "100%",
                boxSizing: "border-box",
                padding: 15,
                border: "1px solid #666666",
                borderRadius: 12,
                fontSize: 16,
              }}
            />
          </label>

          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 16,
            }}
          >
            <span>Password</span>

            <input
              type="password"
              value={password}
              onChange={(event) =>
                setPassword(event.target.value)
              }
              autoComplete="current-password"
              disabled={loading}
              style={{
                width: "100%",
                boxSizing: "border-box",
                padding: 15,
                border: "1px solid #666666",
                borderRadius: 12,
                fontSize: 16,
              }}
            />
          </label>

          <button
            type="submit"
            disabled={loading}
            style={{
              width: "100%",
              marginTop: 22,
              padding: 16,
              border: 0,
              borderRadius: 14,
              background: "#f5a623",
              color: "#111111",
              fontSize: 16,
              fontWeight: 900,
              cursor: loading ? "wait" : "pointer",
              opacity: loading ? 0.6 : 1,
            }}
          >
            {loading ? "Signing in..." : "Open staff scanner"}
          </button>
        </form>
      </section>
    </main>
  );
}