"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useState } from "react";
import { createClient } from "@/lib/supabase/client";

type StatusType = "idle" | "info" | "success" | "error";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  const [message, setMessage] = useState(
    "Log in to access your VIVID+ membership.",
  );

  const [statusType, setStatusType] =
    useState<StatusType>("idle");

  const [loading, setLoading] = useState(false);

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const cleanEmail = email.trim().toLowerCase();

    if (!cleanEmail || !password) {
      setMessage("Enter your email and password.");
      setStatusType("error");
      return;
    }

    setLoading(true);
    setMessage("Signing you in securely...");
    setStatusType("info");

    try {
      const { error } =
        await supabase.auth.signInWithPassword({
          email: cleanEmail,
          password,
        });

      if (error) {
        throw error;
      }

      setMessage("Login successful. Opening your VIVID+ account...");
      setStatusType("success");

      router.replace("/");
      router.refresh();
    } catch (error) {
      const errorMessage =
        error instanceof Error
          ? error.message
          : "Unable to sign in.";

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
          maxWidth: 460,
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
          Welcome back
        </h1>

        <p
          style={{
            margin: "10px 0 0",
            color: "#aaaaaa",
            lineHeight: 1.6,
          }}
        >
          Access your points, membership card and rewards.
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

        <form onSubmit={handleLogin}>
          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 22,
            }}
          >
            <span
              style={{
                fontSize: 14,
                fontWeight: 800,
              }}
            >
              Email
            </span>

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
              style={{
                width: "100%",
                boxSizing: "border-box",
                padding: 15,
                border: "1px solid #555555",
                borderRadius: 14,
                background: "#ffffff",
                color: "#111111",
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
            <span
              style={{
                fontSize: 14,
                fontWeight: 800,
              }}
            >
              Password
            </span>

            <div
              style={{
                position: "relative",
              }}
            >
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(event) =>
                  setPassword(event.target.value)
                }
                placeholder="Enter your password"
                autoComplete="current-password"
                required
                minLength={8}
                disabled={loading}
                style={{
                  width: "100%",
                  boxSizing: "border-box",
                  padding: "15px 92px 15px 15px",
                  border: "1px solid #555555",
                  borderRadius: 14,
                  background: "#ffffff",
                  color: "#111111",
                  fontSize: 16,
                }}
              />

              <button
                type="button"
                onClick={() =>
                  setShowPassword((current) => !current)
                }
                disabled={loading}
                aria-label={
                  showPassword
                    ? "Hide password"
                    : "Show password"
                }
                style={{
                  position: "absolute",
                  top: "50%",
                  right: 10,
                  transform: "translateY(-50%)",
                  padding: "8px 10px",
                  border: 0,
                  borderRadius: 10,
                  background: "#eeeeee",
                  color: "#111111",
                  fontSize: 13,
                  fontWeight: 900,
                  cursor: loading ? "not-allowed" : "pointer",
                }}
              >
                {showPassword ? "Hide" : "Show"}
              </button>
            </div>
          </label>

          <div
            style={{
              marginTop: 12,
              textAlign: "right",
            }}
          >
            <Link
              href="/forgot-password"
              style={{
                color: "#f5a623",
                fontSize: 14,
                fontWeight: 800,
                textDecoration: "none",
              }}
            >
              Forgot password?
            </Link>
          </div>

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
            {loading ? "Signing in..." : "Log in"}
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
          Not a member yet?{" "}
          <Link
            href="/signup"
            style={{
              color: "#f5a623",
              fontWeight: 900,
              textDecoration: "none",
            }}
          >
            Create account
          </Link>
        </div>
      </section>
    </main>
  );
}