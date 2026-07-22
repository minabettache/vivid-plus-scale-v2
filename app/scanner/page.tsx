"use client";

import {
  Suspense,
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react";
import { useSearchParams } from "next/navigation";
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

function extractMemberCode(scannedValue: string): string {
  const value = scannedValue.trim();

  if (!value) return "";

  try {
    const url = new URL(value);
    const code = url.searchParams.get("code");

    if (code) {
      return code.trim();
    }
  } catch {
    // Not a URL, continue below.
  }

  if (value.startsWith("VIVID-MEMBER:")) {
    return value.replace("VIVID-MEMBER:", "").trim();
  }

  return value;
}

function ScannerContent() {
  const searchParams = useSearchParams();

  const scannerRef = useRef<any>(null);
  const lookupStartedRef = useRef(false);

  const codeFromUrl = searchParams.get("code")?.trim() || "";

  const [member, setMember] = useState<ScannedMember | null>(null);
  const [message, setMessage] = useState(
    codeFromUrl
      ? "Looking up member..."
      : "Point the camera at a VIVID+ QR code."
  );
  const [searching, setSearching] = useState(Boolean(codeFromUrl));
  const [cameraMode, setCameraMode] = useState(!codeFromUrl);

  const stopScanner = useCallback(async () => {
    if (!scannerRef.current) return;

    try {
      await scannerRef.current.clear();
    } catch {
      // Scanner may already be stopped.
    }

    scannerRef.current = null;
  }, []);

  const findMember = useCallback(
    async (scannedValue: string) => {
      const memberCode = extractMemberCode(scannedValue);

      if (!memberCode) {
        setMember(null);
        setSearching(false);
        setMessage("Invalid VIVID+ QR code.");
        lookupStartedRef.current = false;
        return;
      }

      setSearching(true);
      setCameraMode(false);
      setMember(null);
      setMessage(`Looking up member: ${memberCode}`);

      try {
        const { data, error } = await supabase
          .from("members")
          .select(
            "id, full_name, phone, email, membership_level, points, qr_code, is_active"
          )
          .eq("qr_code", memberCode)
          .maybeSingle();

        if (error) {
          console.error("Supabase lookup error:", error);
          setMessage(`Database error: ${error.message}`);
          lookupStartedRef.current = false;
          return;
        }

        if (!data) {
          setMessage(`Member not found: ${memberCode}`);
          lookupStartedRef.current = false;
          return;
        }

        setMember(data as ScannedMember);

        setMessage(
          data.is_active === false
            ? "Member found, but membership is inactive."
            : "Member verified."
        );

        await stopScanner();
      } catch (error) {
        console.error("Unexpected lookup error:", error);
        setMessage("Unexpected error while searching for the member.");
        lookupStartedRef.current = false;
      } finally {
        setSearching(false);
      }
    },
    [stopScanner]
  );

  useEffect(() => {
    if (!codeFromUrl || lookupStartedRef.current) return;

    lookupStartedRef.current = true;
    setCameraMode(false);

    void findMember(codeFromUrl);
  }, [codeFromUrl, findMember]);

  useEffect(() => {
    if (codeFromUrl || !cameraMode || member) return;

    let pageActive = true;

    async function startScanner() {
      try {
        const { Html5QrcodeScanner } = await import("html5-qrcode");

        if (!pageActive) return;

        const scanner = new Html5QrcodeScanner(
          "qr-reader",
          {
            fps: 10,
            qrbox: {
              width: 250,
              height: 250,
            },
            rememberLastUsedCamera: true,
          },
          false
        );

        scannerRef.current = scanner;

        scanner.render(
          async (decodedText: string) => {
            if (
              !pageActive ||
              lookupStartedRef.current
            ) {
              return;
            }

            lookupStartedRef.current = true;
            await findMember(decodedText);
          },
          () => {
            // Ignore frames without a readable QR code.
          }
        );
      } catch (error) {
        console.error("Scanner startup error:", error);

        if (pageActive) {
          setMessage(
            "Camera scanner could not start. Please allow camera permission."
          );
        }
      }
    }

    void startScanner();

    return () => {
      pageActive = false;

      if (scannerRef.current) {
        scannerRef.current.clear().catch(() => {});
        scannerRef.current = null;
      }
    };
  }, [cameraMode, codeFromUrl, member, findMember]);

  function scanAnotherMember() {
    window.location.assign("/scanner");
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        background: "#0b0b0b",
        color: "#ffffff",
        padding: "30px 20px",
        textAlign: "center",
        fontFamily: "Arial, sans-serif",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: "480px",
          margin: "0 auto",
        }}
      >
        <h1
          style={{
            color: "#f5a623",
            marginTop: 0,
            marginBottom: "8px",
            fontSize: "30px",
          }}
        >
          VIVID+ Staff Scanner
        </h1>

        <p
          style={{
            color: searching ? "#f5a623" : "#bbbbbb",
            marginBottom: "24px",
            fontWeight: searching ? 700 : 400,
          }}
        >
          {message}
        </p>

        {searching && (
          <div
            style={{
              padding: "22px",
              borderRadius: "14px",
              background: "#171717",
              border: "1px solid #f5a623",
              color: "#f5a623",
              fontWeight: 800,
            }}
          >
            Searching member database...
          </div>
        )}

        {cameraMode && !member && !searching && (
          <div
            id="qr-reader"
            style={{
              width: "100%",
              maxWidth: "420px",
              margin: "0 auto",
              background: "#ffffff",
              borderRadius: "16px",
              overflow: "hidden",
            }}
          />
        )}

        {!member && !searching && !cameraMode && (
          <button
            type="button"
            onClick={scanAnotherMember}
            style={{
              width: "100%",
              padding: "14px",
              border: "none",
              borderRadius: "10px",
              background: "#f5a623",
              color: "#111111",
              fontSize: "16px",
              fontWeight: 800,
              cursor: "pointer",
            }}
          >
            Open camera scanner
          </button>
        )}

        {member && (
          <section
            style={{
              marginTop: "24px",
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
                    ? "rgba(220,38,38,0.15)"
                    : "rgba(34,197,94,0.15)",
                color:
                  member.is_active === false
                    ? "#f87171"
                    : "#4ade80",
                fontWeight: 800,
                textAlign: "center",
              }}
            >
              {member.is_active === false
                ? "MEMBERSHIP INACTIVE"
                : "MEMBER VERIFIED"}
            </div>

            <h2 style={{ marginTop: 0 }}>
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
              <strong>Phone:</strong>{" "}
              {member.phone || "Not provided"}
            </p>

            <p>
              <strong>Email:</strong>{" "}
              {member.email || "Not provided"}
            </p>

            <p style={{ wordBreak: "break-word" }}>
              <strong>Member code:</strong>{" "}
              {member.qr_code || "Not available"}
            </p>

            <button
              type="button"
              onClick={scanAnotherMember}
              style={{
                width: "100%",
                marginTop: "18px",
                padding: "14px",
                border: "none",
                borderRadius: "10px",
                background: "#f5a623",
                color: "#111111",
                fontSize: "16px",
                fontWeight: 800,
                cursor: "pointer",
              }}
            >
              Scan another member
            </button>
          </section>
        )}
      </div>
    </main>
  );
}

export default function ScannerPage() {
  return (
    <Suspense
      fallback={
        <main
          style={{
            minHeight: "100vh",
            background: "#0b0b0b",
            color: "#f5a623",
            display: "grid",
            placeItems: "center",
            fontFamily: "Arial, sans-serif",
            fontWeight: 800,
          }}
        >
          Loading VIVID+ scanner...
        </main>
      }
    >
      <ScannerContent />
    </Suspense>
  );
}