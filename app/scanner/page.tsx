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
  is_active: boolean | null;
};

export default function ScannerPage() {
  const scannerRef = useRef<any>(null);
  const [member, setMember] = useState<ScannedMember | null>(null);
  const [message, setMessage] = useState("Point the camera at a VIVID+ QR code.");

  useEffect(() => {
    let isMounted = true;

    async function startScanner() {
      const { Html5QrcodeScanner } = await import("html5-qrcode");

      if (!isMounted) return;

      const scanner = new Html5QrcodeScanner(
        "qr-reader",
        {
          fps: 10,
          qrbox: { width: 250, height: 250 },
        },
        false
      );

      scannerRef.current = scanner;

      scanner.render(
        async (decodedText: string) => {
          setMessage("Looking up member...");

          const { data, error } = await supabase
            .from("members")
            .select("*")
            .eq("qr_code", decodedText)
            .maybeSingle();

          if (error) {
            console.error(error);
            setMember(null);
            setMessage("Database error. Please try again.");
            return;
          }

          if (!data) {
            setMember(null);
            setMessage("Member not found.");
            return;
          }

          setMember(data);
          setMessage("Member verified.");

          try {
            await scanner.clear();
          } catch {
            // Scanner may already be stopped.
          }
        },
        () => {
          // Ignore normal scanning attempts that do not detect a QR code.
        }
      );
    }

    startScanner();

    return () => {
      isMounted = false;

      if (scannerRef.current) {
        scannerRef.current.clear().catch(() => {});
      }
    };
  }, []);

  return (
    <main
      style={{
        minHeight: "100vh",
        background: "#0b0b0b",
        color: "white",
        padding: "30px 20px",
        textAlign: "center",
      }}
    >
      <h1 style={{ color: "#f5a623", marginBottom: "8px" }}>
        VIVID+ Staff Scanner
      </h1>

      <p style={{ color: "#bbbbbb", marginBottom: "24px" }}>{message}</p>

      <div
        id="qr-reader"
        style={{
          maxWidth: "420px",
          margin: "0 auto",
          background: "white",
          borderRadius: "16px",
          overflow: "hidden",
        }}
      />

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
          <h2 style={{ marginTop: 0 }}>{member.full_name || "VIVID+ Member"}</h2>
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
            <strong>Member ID:</strong> {member.qr_code}
          </p>
        </section>
      )}
    </main>
  );
}