"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function StaffLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setLoading(true);

    try {
      const supabase = createClient();
      const { error: signInError } = await supabase.auth.signInWithPassword({ email, password });
      if (signInError) throw signInError;
      router.replace("/staff/dashboard");
      router.refresh();
    } catch (signInError) {
      setError(signInError instanceof Error ? signInError.message : "Unable to sign in.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", padding: 24, background: "#090909", color: "white" }}>
      <form onSubmit={submit} style={{ width: "100%", maxWidth: 420, padding: 28, border: "1px solid #2b2b2b", borderRadius: 24, background: "#121212" }}>
        <p style={{ color: "#f5a623", fontWeight: 800, letterSpacing: ".12em" }}>VIVID+ STAFF</p>
        <h1 style={{ marginTop: 8 }}>Secure sign in</h1>
        <label style={{ display: "grid", gap: 8, marginTop: 22 }}>Email
          <input required type="email" value={email} onChange={(e) => setEmail(e.target.value)} style={{ padding: 14, borderRadius: 12 }} />
        </label>
        <label style={{ display: "grid", gap: 8, marginTop: 16 }}>Password
          <input required type="password" value={password} onChange={(e) => setPassword(e.target.value)} style={{ padding: 14, borderRadius: 12 }} />
        </label>
        {error && <p role="alert" style={{ color: "#ff8d8d" }}>{error}</p>}
        <button disabled={loading} type="submit" style={{ width: "100%", marginTop: 22, padding: 15, border: 0, borderRadius: 14, fontWeight: 800, cursor: "pointer", background: "#f5a623" }}>
          {loading ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </main>
  );
}
