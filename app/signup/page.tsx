"use client";

import Link from "next/link";
import { FormEvent, useState } from "react";
import { createClient } from "@/lib/supabase/client";

type StatusType = "idle" | "info" | "success" | "error";

export default function SignupPage() {
  const supabase = createClient();

  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] =
    useState("");

  const [message, setMessage] = useState(
    "Create your VIVID+ membership account."
  );

  const [statusType, setStatusType] =
    useState<StatusType>("idle");

  const [loading, setLoading] = useState(false);

  async function handleSignup(
    event: FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();

    const cleanName = fullName.trim();
    const cleanEmail = email.trim().toLowerCase();

    if (cleanName.length < 2) {
      setMessage("Enter your full name.");
      setStatusType("error");
      return;
    }

    if (!cleanEmail) {
      setMessage("Enter a valid email address.");
      setStatusType("error");
      return;
    }

    if (password.length < 8) {
      setMessage(
        "Your password must contain at least 8 characters."
      );
      setStatusType("error");
      return;
    }

    if (password !== confirmPassword) {
      setMessage("Your passwords do not match.");
      setStatusType("error");
      return;
    }

    setLoading(true);
    setMessage("Creating your VIVID+ account...");
    setStatusType("info");

    try {
      const redirectUrl =
        typeof window !== "undefined"
          ? `${window.location.origin}/auth/callback`
          : undefined;

      const { data, error } = await supabase.auth.signUp({
        email: cleanEmail,
        password,
        options: {
          emailRedirectTo: redirectUrl,
          data: {
            full_name: cleanName,
          },
        },
      });

      if (error) {
        throw error;
      }

      if (data.session) {
        setMessage(
          "Account created successfully. You can now access your account."
        );
      } else {
        setMessage(
          "Account created. Check your email and confirm your address before logging in."
        );
      }

      setStatusType("success");
      setPassword("");
      setConfirmPassword("");
    } catch (error) {
      const errorMessage =
        error instanceof Error
          ? error.message
          : "Unable to create your account.";

      setMessage(errorMessage);
      setStatusType("error");
    } finally {
      setLoading(false);
    }
  }

  const statusBackground =
    statusType === "success"
      ? "#12351f"
      : statusType === "error"
        ? "#3b1515"
        : statusType === "info"
          ? "#242424"
          : "#171717";

  const statusBorder =
    statusType === "success"
      ? "#279653"
      : statusType === "error"
        ? "#d14b4b"
        : "#333333";

  return (
    <main
      style={{
        minHeight: "100vh",
        padding: "32px 20px",
        background:
          "radial-gradient(circle at top, #242424 0%, #090909 48%)",
        color: "#ffffff",
        display: "grid",
        placeItems: "center",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: 500,
          padding: 28,
          border: "1px solid #333333",
          borderRadius: 24,
          background:
            "linear-gradient(145deg, #1d1d1d 0%, #101010 100%)",
          boxShadow: "0 24px 70px rgba(0, 0, 0, 0.45)",
        }}
      >
        <p
          style={{
            margin: 0,
            color: "#f5a623",
            fontSize: 14,
            fontWeight: 900,
            letterSpacing: "0.08em",
          }}
        >
          VIVID+
        </p>

        <h1
          style={{
            margin: "14px 0 0",
            fontSize: "clamp(2rem, 8vw, 3rem)",
          }}
        >
          Join VIVID+
        </h1>

        <p
          style={{
            margin: "10px 0 0",
            color: "#aaaaaa",
            lineHeight: 1.6,
          }}
        >
          Create your account and start earning rewards.
        </p>

        <div
          role="status"
          aria-live="polite"
          style={{
            marginTop: 22,
            padding: 14,
            border: `1px solid ${statusBorder}`,
            borderRadius: 14,
            background: statusBackground,
            color: "#eeeeee",
            lineHeight: 1.5,
          }}
        >
          {message}
        </div>

        <form onSubmit={handleSignup}>
          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 22,
            }}
          >
            <span style={{ fontWeight: 800 }}>
              Full name
            </span>

            <input
              value={fullName}
              onChange={(event) =>
                setFullName(event.target.value)
              }
              placeholder="Your full name"
              autoComplete="name"
              required
              disabled={loading}
              maxLength={100}
              style={inputStyle}
            />
          </label>

          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 16,
            }}
          >
            <span style={{ fontWeight: 800 }}>Email</span>

            <input
              type="email"
              value={email}
              onChange={(event) =>
                setEmail(event.target.value)
              }
              placeholder="you@example.com"
              autoComplete="email"
              required
              disabled={loading}
              style={inputStyle}
            />
          </label>

          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 16,
            }}
          >
            <span style={{ fontWeight: 800 }}>
              Password
            </span>

            <input
              type="password"
              value={password}
              onChange={(event) =>
                setPassword(event.target.value)
              }
              placeholder="Minimum 8 characters"
              autoComplete="new-password"
              required
              minLength={8}
              disabled={loading}
              style={inputStyle}
            />
          </label>

          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 16,
            }}
          >
            <span style={{ fontWeight: 800 }}>
              Confirm password
            </span>

            <input
              type="password"
              value={confirmPassword}
              onChange={(event) =>
                setConfirmPassword(event.target.value)
              }
              placeholder="Enter password again"
              autoComplete="new-password"
              required
              minLength={8}
              disabled={loading}
              style={inputStyle}
            />
          </label>

          <button
            type="submit"
            disabled={loading}
            style={{
              width: "100%",
              marginTop: 24,
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
            {loading ? "Creating account..." : "Create account"}
          </button>
        </form>

        <div
          style={{
            marginTop: 24,
            paddingTop: 20,
            borderTop: "1px solid #333333",
            textAlign: "center",
            color: "#aaaaaa",
          }}
        >
          Already registered?{" "}
          <Link
            href="/login"
            style={{
              color: "#f5a623",
              fontWeight: 900,
              textDecoration: "none",
            }}
          >
            Log in
          </Link>
        </div>
      </section>
    </main>
  );
}

const inputStyle = {
  width: "100%",
  boxSizing: "border-box" as const,
  padding: 15,
  border: "1px solid #555555",
  borderRadius: 14,
  background: "#ffffff",
  color: "#111111",
  fontSize: 16,
};