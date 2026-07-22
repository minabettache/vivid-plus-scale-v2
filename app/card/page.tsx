"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { loadMember } from "@/lib/member";
import type { Member } from "@/lib/types";

export default function DigitalCardPage() {
  const router = useRouter();
  const [member, setMember] = useState<Member | null>(null);

  useEffect(() => {
    async function getMember() {
      const savedMember = await loadMember();
      setMember(savedMember);
    }

    getMember();
  }, []);

  if (!member) {
    return (
      <main
        style={{
          minHeight: "100vh",
          background: "#0b0b0b",
          color: "white",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        Loading digital card...
      </main>
    );
  }

  // ✅ THIS IS THE FIX
  const qrValue = `VIVID-MEMBER:${member.memberId}`;

  const qrImageUrl =
    "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" +
    encodeURIComponent(qrValue);

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
      <button
        onClick={() => router.push("/")}
        style={{
          background: "transparent",
          color: "#f5a623",
          border: "1px solid #f5a623",
          borderRadius: "10px",
          padding: "10px 18px",
          cursor: "pointer",
          marginBottom: "28px",
        }}
      >
        ← Back
      </button>

      <section
        style={{
          maxWidth: "420px",
          margin: "0 auto",
          padding: "28px",
          borderRadius: "24px",
          border: "1px solid #f5a623",
          background:
            "linear-gradient(145deg, #2a1407, #171717 55%, #0f0f0f)",
          boxShadow: "0 20px 60px rgba(245, 166, 35, 0.18)",
        }}
      >
        <p
          style={{
            color: "#f5a623",
            fontWeight: "bold",
            letterSpacing: "2px",
            marginBottom: "8px",
          }}
        >
          VIVID+ DIGITAL CARD
        </p>

        <h1 style={{ margin: "0 0 6px" }}>
          {member.name}
        </h1>

        <p style={{ color: "#bbbbbb", marginTop: 0 }}>
          {member.membershipLevel} Member • {member.points} points
        </p>

        <div
          style={{
            background: "white",
            padding: "18px",
            borderRadius: "18px",
            display: "inline-block",
            margin: "22px 0",
          }}
        >
          <img
            src={qrImageUrl}
            alt="VIVID+ Membership QR"
            width={260}
            height={260}
            style={{ display: "block" }}
          />
        </div>

        <h2
          style={{
            color: "#f5a623",
            marginBottom: "8px",
          }}
        >
          {member.memberId}
        </h2>

        <p
          style={{
            color: "#999",
            fontSize: "14px",
            marginBottom: "10px",
          }}
        >
          Present this QR code to VIVID+ staff.
        </p>

        <p
          style={{
            color: "#777",
            fontSize: "12px",
            wordBreak: "break-all",
          }}
        >
          {qrValue}
        </p>
      </section>
    </main>
  );
}