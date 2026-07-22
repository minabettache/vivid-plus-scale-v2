"use client";

import { useEffect, useRef, useState } from "react";
import { supabase } from "@/lib/supabase";

type ScannedMember = {
  id: number;
  full_name: string | null;
  phone: string | null;
  email: string | null;
  membership_level: string | null;
  points: number | null;
  qr_code: string | null;
  member_id?: string | null;
  is_active: boolean | null;
};

function extractMemberCode(scannedValue: string) {
  const value = scannedValue.trim();

  try {
    const url = new URL(value);
    const code = url.searchParams.get("code");

    if (code) {
      return code.trim();
    }
  } catch {
    // Not a URL.
  }

  if (value.startsWith("VIVID-MEMBER:")) {
    return value.replace("VIVID-MEMBER:", "").trim();
  }

  return value;
}

export default function ScannerPage() {
  const scannerRef = useRef<any>(null);
  const lookupStartedRef = useRef(false);

  const [member, setMember] = useState<ScannedMember | null>(null);
  const [message, setMessage] = useState(
    "Point the camera at a VIVID+ QR code."
  );
  const [searching, setSearching] = useState(false);

  async function findMember(scannedValue: string) {
    if (searching) return;

    const memberCode = extractMemberCode(scannedValue);

    if (!memberCode) {
      setMember(null);
      setMessage("Invalid VIVID+ QR code.");
      return;
    }

    setSearching(true);
    setMember(null);
    setMessage("Looking up member...");

    const { data, error } = await supabase
      .from("members")
      .select(
        "id, full_name, phone, email, membership_level, points, qr_code, member_id, is_active"
      )
      .or(`qr_code.eq.${memberCode},member_id.eq.${memberCode}`)
      .maybeSingle();

    if (error) {
      console.error("Member lookup error:", error);
      setMessage("Database error. Please try again.");
      setSearching(false);
      return;
    }

    if (!data) {
      setMessage(`Member not found: ${memberCode}`);
      setSearching(false);
      return;
    }

    setMember(data);

    setMessage(
      data.is_active === false
        ? "Member found, but the membership is inactive."
        : "Member verified."
    );

    setSearching(false);

    if (scannerRef.current) {
      try {
        await scannerRef.current.clear();
      } catch {
        // Scanner may already be stopped.
      }
    }
  }

  useEffect(() => {
    let isMounted = true;

    const params = new URLSearchParams(window.location.search);
    const codeFromUrl = params.get("code");

    if (codeFromUrl && !lookupStartedRef.current) {
      lookupStartedRef.current = true;
      void findMember(codeFromUrl);
      return;
    }

    async function startScanner() {
      try {
        const { Html5QrcodeScanner } = await import("html5-qrcode");

        if (!isMounted) return;

        const scanner = new Html5QrcodeScanner(
          "qr-reader",
          {
            fps: 10,
            qrbox: {
              width: 250,
              height: 250,
            },
          },
          false
        );

        scannerRef.current = scanner;

        scanner.render(
          async (decodedText: string) => {
            if (lookupStartedRef.current) return;

            lookupStartedRef.current = true;
            await findMember(decodedText);
          },
          () => {
            // Ignore frames without a QR code.
          }
        );
      } catch (error) {
        console.error("Scanner startup error:", error);
        setMessage("Camera scanner could not start.");
      }
    }

    void startScanner();

    return () => {
      isMounted = false;

      if (scannerRef.current) {
        scannerRef.current.clear().catch(() => {});
      }
    };
  }, []);

  function scanAnotherMember() {
    window.location.href = "/scanner";
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        background: "#0b0b0b",
        color: "#ffffff",
        padding: "30px 20px",
        textAlign: "center",
      }}
    >
      <h1
        style={{
          color: "#f5a623",
          marginBottom: "8px",
        }}
      >
        VIVID+ Staff Scanner
      </h1>

      <p
        style={{
          color: "#bbbbbb",
          marginBottom: "24px",
        }}
      >
        {message}
      </p>

      {!member && !searching && (
        <div
          id="qr-reader"
          style={{
            maxWidth: "420px",
            margin: "0 auto",
            background: "#ffffff",
            borderRadius: "16px",
            overflow: "hidden",
          }}
        />
      )}

      {searching && (
        <p
          style={{
            color: "#f5a623",
            fontWeight: 700,
          }}
        >
          Searching member database...
        </p>
      )}

      {member && (
        <section
          style={{
            maxWidth: "420px",
            margin: "24px auto 0",
            padding: "24px",
            border: "1px solid #f5a623",
            borderRadius: "18px",
            background: "#171717",
            textAlign: "left",
          }}
        >
          <div
            style={{
              marginBottom: "18px",
              padding: "12px",
              borderRadius: "10px",
              background:
                member.is_active === false
                  ? "rgba(220, 38, 38, 0.15)"
                  : "rgba(34, 197, 94, 0.15)",
              color:
                member.is_active === false ? "#f87171" : "#4ade80",
              fontWeight: 800,
              textAlign: "center",
            }}
          >
            {member.is_active === false
              ? "MEMBERSHIP INACTIVE"
              : "MEMBER VERIFIED"}
          </div>

          <h2
            style={{
              marginTop: 0,
              color: "#ffffff",
            }}
          >
            {member.full_name || "VIVID+ Member"}
          </h2>

          <p>
            <strong>Membership:</strong>{" "}
            {member.membership_level || "Member"}
          </p>

          <p>
            <strong>Points:</strong> {member.points ?? 0}
          </p>

          <p>
            <strong>Status:</strong>{" "}
            {member.is_active === false ? "Inactive" : "Active"}
          </p>

          <p>
            <strong>Phone:</strong> {member.phone || "Not provided"}
          </p>

          <p>
            <strong>Email:</strong> {member.email || "Not provided"}
          </p>

          <p style={{ wordBreak: "break-word" }}>
            <strong>Member code:</strong>{" "}
            {member.qr_code || member.member_id || "Not available"}
          </p>

          <button
            type="button"
            onClick={scanAnotherMember}
            style={{
              width: "100%",
              marginTop: "18px",
              padding: "13px 16px",
              border: "none",
              borderRadius: "10px",
              background: "#f5a623",
              color: "#111111",
              fontWeight: 800,
              cursor: "pointer",
            }}
          >
            Scan another member
          </button>
        </section>
      )}
    </main>
  );
}