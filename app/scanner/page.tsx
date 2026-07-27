"use client";

import {
  BrowserQRCodeReader,
  type IScannerControls,
} from "@zxing/browser";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react";

type MemberProfile = {
  id: number | string;
  full_name: string | null;
  phone: string | null;
  email: string | null;
  membership_level: string | null;
  points: number;
  birthday: string | null;
  qr_code: string;
  is_active: boolean;
  lifetime_points: number;
  total_visits: number;
  total_spent: number;
  last_visit_at: string | null;
  created_at: string;
};

type PaymentMethod = "cash" | "card";

type SaleResult = {
  member_name?: string;
  amount_paid?: number;
  points_earned?: number;
  new_balance?: number;
  membership_level?: string;
  new_tier?: string;
  tier_upgraded?: boolean;
};

function extractMemberCode(raw: string) {
  try {
    const url = new URL(raw);

    return (
      url.searchParams.get("code")?.trim() ||
      url.searchParams.get("memberCode")?.trim() ||
      raw.trim()
    );
  } catch {
    return raw.trim();
  }
}

function formatDate(value: string | null) {
  if (!value) {
    return "Not available";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "Not available";
  }

  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

function formatDateTime(value: string | null) {
  if (!value) {
    return "No previous visit";
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "No previous visit";
  }

  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

function formatMoney(value: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(value);
}

export default function ScannerPage() {
  const videoRef = useRef<HTMLVideoElement>(null);
  const controlsRef = useRef<IScannerControls | null>(null);
  const readerRef = useRef<BrowserQRCodeReader | null>(null);
  const scanningRef = useRef(false);

  const [memberCode, setMemberCode] = useState("");
  const [member, setMember] = useState<MemberProfile | null>(null);

  const [amountPaid, setAmountPaid] = useState("");
  const [paymentMethod, setPaymentMethod] =
    useState<PaymentMethod>("card");
  const [note, setNote] = useState("");

  const [message, setMessage] = useState("");
  const [messageType, setMessageType] = useState<
    "info" | "success" | "error"
  >("info");

  const [lookupLoading, setLookupLoading] = useState(false);
  const [saleLoading, setSaleLoading] = useState(false);
  const [cameraLoading, setCameraLoading] = useState(true);

  const lookupMember = useCallback(
    async (codeOverride?: string) => {
      const code = (codeOverride ?? memberCode).trim();

      if (!code) {
        setMember(null);
        setMessageType("error");
        setMessage("Scan or enter a member code first.");
        return;
      }

      setLookupLoading(true);
      setMessage("");

      try {
        const response = await fetch("/api/members/lookup", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            memberCode: code,
          }),
        });

        const payload = await response.json();

        if (!response.ok) {
          throw new Error(
            payload.error || "Unable to look up member.",
          );
        }

        setMember(payload.member as MemberProfile);
        setMemberCode(code);
        setMessageType("success");
        setMessage("Member profile loaded successfully.");
      } catch (error) {
        setMember(null);
        setMessageType("error");
        setMessage(
          error instanceof Error
            ? error.message
            : "Unable to look up member.",
        );
      } finally {
        setLookupLoading(false);
      }
    },
    [memberCode],
  );

  const startScanner = useCallback(async () => {
    if (!videoRef.current || scanningRef.current) {
      return;
    }

    controlsRef.current?.stop();
    controlsRef.current = null;

    if (!readerRef.current) {
      readerRef.current = new BrowserQRCodeReader();
    }

    scanningRef.current = true;
    setCameraLoading(true);
    setMessageType("info");
    setMessage("Starting camera...");

    try {
      controlsRef.current =
        await readerRef.current.decodeFromVideoDevice(
          undefined,
          videoRef.current,
          (result) => {
            if (!result) {
              return;
            }

            const code = extractMemberCode(result.getText());

            controlsRef.current?.stop();
            controlsRef.current = null;
            scanningRef.current = false;

            setMemberCode(code);
            setMessageType("info");
            setMessage("QR code scanned. Loading member...");

            void lookupMember(code);
          },
        );

      setMessageType("info");
      setMessage(
        "Camera ready. Hold the member QR code in view.",
      );
    } catch (error) {
      scanningRef.current = false;
      setMessageType("error");
      setMessage(
        error instanceof Error
          ? error.message
          : "Camera could not start.",
      );
    } finally {
      setCameraLoading(false);
    }
  }, [lookupMember]);

  useEffect(() => {
    void startScanner();

    return () => {
      scanningRef.current = false;
      controlsRef.current?.stop();
      controlsRef.current = null;
    };
  }, [startScanner]);

  async function completeSale() {
    const numericAmount = Number(amountPaid);

    if (!memberCode.trim() || !member) {
      setMessageType("error");
      setMessage("Scan or look up a member first.");
      return;
    }

    if (
      !Number.isFinite(numericAmount) ||
      numericAmount <= 0 ||
      numericAmount > 100000
    ) {
      setMessageType("error");
      setMessage(
        "Enter a valid sale amount between $0.01 and $100,000.",
      );
      return;
    }

    setSaleLoading(true);
    setMessage("");

    try {
      const response = await fetch("/api/sales/record", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          memberCode: memberCode.trim(),
          amountPaid: numericAmount,
          paymentMethod,
          note: note.trim() || null,
          idempotencyKey: crypto.randomUUID(),
        }),
      });

      const payload = await response.json();

      if (!response.ok) {
        throw new Error(
          payload.error || "Unable to record sale.",
        );
      }

      const result = (payload.result ?? {}) as SaleResult;

      const memberName =
        result.member_name ||
        member.full_name ||
        "Member";

      const pointsEarned =
        result.points_earned ??
        payload.pointsEarned ??
        payload.points_earned;

      const newBalance =
        result.new_balance ??
        payload.newBalance ??
        payload.new_balance;

      const upgradedTier =
        result.new_tier ||
        result.membership_level ||
        payload.newTier ||
        payload.membershipLevel;

      let successMessage = `${formatMoney(
        numericAmount,
      )} sale recorded for ${memberName}.`;

      if (typeof pointsEarned === "number") {
        successMessage += ` ${pointsEarned.toLocaleString()} points earned.`;
      }

      if (typeof newBalance === "number") {
        successMessage += ` New balance: ${newBalance.toLocaleString()} points.`;
      }

      if (
        result.tier_upgraded &&
        typeof upgradedTier === "string"
      ) {
        successMessage += ` Tier upgraded to ${upgradedTier}.`;
      }

      setMessageType("success");
      setMessage(successMessage);

      setAmountPaid("");
      setNote("");

      await lookupMember(memberCode);
    } catch (error) {
      setMessageType("error");
      setMessage(
        error instanceof Error
          ? error.message
          : "Unable to record sale.",
      );
    } finally {
      setSaleLoading(false);
    }
  }

  function resetScanner() {
    controlsRef.current?.stop();
    controlsRef.current = null;
    scanningRef.current = false;

    setMemberCode("");
    setMember(null);
    setAmountPaid("");
    setPaymentMethod("card");
    setNote("");
    setMessage("");
    setMessageType("info");

    void startScanner();
  }

  const busy =
    lookupLoading ||
    saleLoading ||
    cameraLoading;

  const saleDisabled =
    saleLoading ||
    !member ||
    !memberCode.trim() ||
    !amountPaid.trim();

  return (
    <main
      style={{
        minHeight: "100vh",
        padding: 24,
        background: "#090909",
        color: "#ffffff",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: 760,
          margin: "0 auto",
        }}
      >
        <header>
          <p
            style={{
              margin: 0,
              color: "#f5a623",
              fontWeight: 900,
              letterSpacing: "0.08em",
              fontSize: 13,
            }}
          >
            VIVID+ SALES SCANNER
          </p>

          <h1
            style={{
              margin: "12px 0 0",
              fontSize: "clamp(2.2rem, 8vw, 4.5rem)",
              lineHeight: 0.95,
            }}
          >
            Scan member
            <br />
            and record sale
          </h1>

          <p
            style={{
              margin: "16px 0 0",
              color: "#aaaaaa",
              lineHeight: 1.6,
            }}
          >
            Scan the customer’s VIVID+ card, enter today’s
            purchase, and points will be calculated automatically.
          </p>
        </header>

        <section
          style={{
            marginTop: 28,
            padding: 18,
            borderRadius: 24,
            border: "1px solid #303030",
            background: "#121212",
          }}
        >
          <video
            ref={videoRef}
            muted
            playsInline
            style={{
              display: "block",
              width: "100%",
              minHeight: 260,
              borderRadius: 18,
              background: "#000000",
              objectFit: "cover",
            }}
          />

          <button
            type="button"
            onClick={() => void startScanner()}
            disabled={cameraLoading || scanningRef.current}
            style={{
              width: "100%",
              marginTop: 14,
              padding: 13,
              borderRadius: 13,
              border: "1px solid #3b3b3b",
              background: "#202020",
              color: "#ffffff",
              fontWeight: 800,
              cursor: "pointer",
              opacity:
                cameraLoading || scanningRef.current
                  ? 0.6
                  : 1,
            }}
          >
            {cameraLoading
              ? "Starting camera..."
              : "Restart camera"}
          </button>
        </section>

        <section
          style={{
            marginTop: 20,
            padding: 22,
            borderRadius: 22,
            border: "1px solid #303030",
            background: "#141414",
          }}
        >
          <label
            style={{
              display: "grid",
              gap: 8,
              fontWeight: 800,
            }}
          >
            Member code

            <input
              value={memberCode}
              onChange={(event) => {
                setMemberCode(event.target.value);
                setMember(null);
              }}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  void lookupMember();
                }
              }}
              placeholder="Scan or enter member code"
              autoComplete="off"
              style={{
                width: "100%",
                boxSizing: "border-box",
                padding: 14,
                borderRadius: 12,
                border: "1px solid #404040",
                background: "#ffffff",
                color: "#111111",
                fontSize: 16,
              }}
            />
          </label>

          <button
            type="button"
            onClick={() => void lookupMember()}
            disabled={lookupLoading || !memberCode.trim()}
            style={{
              width: "100%",
              marginTop: 14,
              padding: 14,
              border: 0,
              borderRadius: 13,
              background: "#ffffff",
              color: "#111111",
              fontWeight: 900,
              cursor: "pointer",
              opacity:
                lookupLoading || !memberCode.trim()
                  ? 0.6
                  : 1,
            }}
          >
            {lookupLoading
              ? "Loading member..."
              : "Look up member"}
          </button>
        </section>

        {member && (
          <section
            style={{
              marginTop: 20,
              padding: 24,
              borderRadius: 24,
              border: "1px solid #4b3a1a",
              background:
                "linear-gradient(145deg, #211a0f 0%, #121212 65%)",
            }}
          >
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "flex-start",
                gap: 18,
                flexWrap: "wrap",
              }}
            >
              <div>
                <p
                  style={{
                    margin: 0,
                    color: "#f5a623",
                    fontSize: 13,
                    fontWeight: 900,
                    letterSpacing: "0.08em",
                  }}
                >
                  MEMBER FOUND
                </p>

                <h2
                  style={{
                    margin: "10px 0 0",
                    fontSize: 30,
                  }}
                >
                  {member.full_name || "VIVID+ Member"}
                </h2>

                <p
                  style={{
                    margin: "8px 0 0",
                    color: "#b8b8b8",
                  }}
                >
                  {member.membership_level || "Member"} membership
                </p>
              </div>

              <div
                style={{
                  padding: "12px 16px",
                  borderRadius: 15,
                  background: "#f5a623",
                  color: "#111111",
                  textAlign: "center",
                }}
              >
                <strong
                  style={{
                    display: "block",
                    fontSize: 27,
                  }}
                >
                  {member.points.toLocaleString()}
                </strong>

                <span
                  style={{
                    fontSize: 12,
                    fontWeight: 900,
                  }}
                >
                  POINTS
                </span>
              </div>
            </div>

            <div
              style={{
                display: "grid",
                gridTemplateColumns:
                  "repeat(auto-fit, minmax(150px, 1fr))",
                gap: 12,
                marginTop: 24,
              }}
            >
              <ProfileStat
                label="Lifetime points"
                value={member.lifetime_points.toLocaleString()}
              />

              <ProfileStat
                label="Total visits"
                value={member.total_visits.toLocaleString()}
              />

              <ProfileStat
                label="Total spent"
                value={formatMoney(member.total_spent)}
              />

              <ProfileStat
                label="Birthday"
                value={formatDate(member.birthday)}
              />
            </div>

            <div
              style={{
                marginTop: 14,
                padding: 15,
                borderRadius: 14,
                background: "rgba(255,255,255,0.05)",
              }}
            >
              <span
                style={{
                  display: "block",
                  color: "#9a9a9a",
                  fontSize: 12,
                  fontWeight: 800,
                  textTransform: "uppercase",
                }}
              >
                Last visit
              </span>

              <strong
                style={{
                  display: "block",
                  marginTop: 7,
                }}
              >
                {formatDateTime(member.last_visit_at)}
              </strong>
            </div>
          </section>
        )}

        <section
          style={{
            marginTop: 20,
            padding: 22,
            borderRadius: 22,
            border: "1px solid #303030",
            background: "#141414",
          }}
        >
          <p
            style={{
              margin: 0,
              color: "#f5a623",
              fontSize: 12,
              fontWeight: 900,
              letterSpacing: "0.08em",
            }}
          >
            TODAY&apos;S SALE
          </p>

          <h2 style={{ margin: "8px 0 0" }}>
            Record customer purchase
          </h2>

          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 20,
              fontWeight: 800,
            }}
          >
            Amount paid

            <div
              style={{
                position: "relative",
              }}
            >
              <span
                style={{
                  position: "absolute",
                  left: 15,
                  top: "50%",
                  transform: "translateY(-50%)",
                  color: "#555555",
                  fontWeight: 900,
                  pointerEvents: "none",
                }}
              >
                $
              </span>

              <input
                type="number"
                min="0.01"
                max="100000"
                step="0.01"
                inputMode="decimal"
                value={amountPaid}
                onChange={(event) =>
                  setAmountPaid(event.target.value)
                }
                placeholder="0.00"
                style={{
                  width: "100%",
                  boxSizing: "border-box",
                  padding: "14px 14px 14px 34px",
                  borderRadius: 12,
                  border: "1px solid #404040",
                  background: "#ffffff",
                  color: "#111111",
                  fontSize: 18,
                  fontWeight: 800,
                }}
              />
            </div>
          </label>

          <fieldset
            style={{
              margin: "18px 0 0",
              padding: 0,
              border: 0,
            }}
          >
            <legend
              style={{
                marginBottom: 9,
                fontWeight: 800,
              }}
            >
              Payment method
            </legend>

            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: 10,
              }}
            >
              <PaymentButton
                label="Card"
                selected={paymentMethod === "card"}
                onClick={() => setPaymentMethod("card")}
              />

              <PaymentButton
                label="Cash"
                selected={paymentMethod === "cash"}
                onClick={() => setPaymentMethod("cash")}
              />
            </div>
          </fieldset>

          <label
            style={{
              display: "grid",
              gap: 8,
              marginTop: 18,
              fontWeight: 800,
            }}
          >
            Note{" "}
            <span
              style={{
                color: "#888888",
                fontSize: 13,
                fontWeight: 600,
              }}
            >
              Optional
            </span>

            <textarea
              value={note}
              maxLength={500}
              rows={3}
              onChange={(event) =>
                setNote(event.target.value)
              }
              placeholder="Add a receipt number or staff note"
              style={{
                width: "100%",
                boxSizing: "border-box",
                padding: 14,
                borderRadius: 12,
                border: "1px solid #404040",
                background: "#ffffff",
                color: "#111111",
                fontSize: 16,
                resize: "vertical",
              }}
            />
          </label>

          <button
            type="button"
            onClick={() => void completeSale()}
            disabled={saleDisabled}
            style={{
              width: "100%",
              marginTop: 18,
              padding: 16,
              border: 0,
              borderRadius: 14,
              fontWeight: 900,
              fontSize: 16,
              background: "#f5a623",
              color: "#111111",
              cursor: "pointer",
              opacity: saleDisabled ? 0.55 : 1,
            }}
          >
            {saleLoading
              ? "Recording sale..."
              : "Complete sale securely"}
          </button>

          <p
            style={{
              margin: "12px 0 0",
              color: "#8f8f8f",
              fontSize: 13,
              lineHeight: 1.5,
              textAlign: "center",
            }}
          >
            Points, spending totals, visits, and membership tier
            are updated automatically.
          </p>
        </section>

        {message && (
          <p
            role="status"
            aria-live="polite"
            style={{
              marginTop: 18,
              padding: 15,
              borderRadius: 14,
              border:
                messageType === "success"
                  ? "1px solid #315d3a"
                  : messageType === "error"
                    ? "1px solid #713333"
                    : "1px solid #333333",
              background:
                messageType === "success"
                  ? "#102417"
                  : messageType === "error"
                    ? "#2b1111"
                    : "#181818",
              color:
                messageType === "success"
                  ? "#b7f7c4"
                  : messageType === "error"
                    ? "#ffb8b8"
                    : "#eeeeee",
            }}
          >
            {message}
          </p>
        )}

        <button
          type="button"
          onClick={resetScanner}
          disabled={busy}
          style={{
            width: "100%",
            marginTop: 18,
            padding: 14,
            borderRadius: 14,
            border: "1px solid #3a3a3a",
            background: "transparent",
            color: "#ffffff",
            fontWeight: 800,
            cursor: "pointer",
            opacity: busy ? 0.5 : 1,
          }}
        >
          Scan another member
        </button>
      </section>
    </main>
  );
}

function PaymentButton({
  label,
  selected,
  onClick,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={selected}
      style={{
        padding: 14,
        borderRadius: 13,
        border: selected
          ? "2px solid #f5a623"
          : "1px solid #454545",
        background: selected ? "#2b2111" : "#202020",
        color: selected ? "#f5a623" : "#ffffff",
        fontWeight: 900,
        cursor: "pointer",
      }}
    >
      {label}
    </button>
  );
}

function ProfileStat({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <article
      style={{
        padding: 15,
        borderRadius: 14,
        background: "rgba(255,255,255,0.05)",
      }}
    >
      <span
        style={{
          display: "block",
          color: "#999999",
          fontSize: 12,
          fontWeight: 800,
          textTransform: "uppercase",
        }}
      >
        {label}
      </span>

      <strong
        style={{
          display: "block",
          marginTop: 8,
          fontSize: 18,
        }}
      >
        {value}
      </strong>
    </article>
  );
}