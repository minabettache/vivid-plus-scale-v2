"use client";

import {
  Suspense,
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react";
import { useSearchParams } from "next/navigation";
import {
  Camera,
  CheckCircle2,
  ChevronLeft,
  CircleDollarSign,
  Flashlight,
  Loader2,
  Plus,
  QrCode,
  RefreshCw,
  Search,
  SwitchCamera,
  UserRound,
  X,
} from "lucide-react";

import { supabase } from "@/lib/supabase";

type Member = {
  id: number;
  full_name: string | null;
  phone: string | null;
  email: string | null;
  membership_level: string | null;
  points: number | null;
  qr_code: string | null;
  is_active: boolean | null;
};

type CameraDevice = {
  deviceId: string;
  label: string;
};

type ScannerControls = {
  stop: () => void;
  switchTorch?: (on: boolean) => Promise<void>;
};

type AlertMessage = {
  type: "success" | "error" | "info";
  text: string;
} | null;

const CAMERA_STORAGE_KEY = "vivid-plus-rear-camera";

function extractMemberCode(value: string): string {
  const cleanedValue = value.trim();

  if (!cleanedValue) {
    return "";
  }

  try {
    const url = new URL(cleanedValue);

    return (
      url.searchParams.get("code")?.trim() ||
      url.searchParams.get("member")?.trim() ||
      cleanedValue
    );
  } catch {
    // The scanned value is a member code rather than a URL.
  }

  return cleanedValue
    .replace(/^VIVID-MEMBER:/i, "")
    .trim();
}

function isRearCameraLabel(label: string): boolean {
  return /back|rear|environment|world|traseira|trasera/i.test(
    label
  );
}

function ScannerContent() {
  const searchParams = useSearchParams();
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const controlsRef = useRef<ScannerControls | null>(null);
  const scanningLockRef = useRef(false);
  const mountedRef = useRef(true);

  const urlCode = searchParams.get("code")?.trim() || "";

  const [member, setMember] = useState<Member | null>(null);
  const [status, setStatus] = useState(
    urlCode
      ? "Looking up member..."
      : "Opening rear camera..."
  );

  const [alert, setAlert] = useState<AlertMessage>(null);
  const [searching, setSearching] = useState(Boolean(urlCode));
  const [cameraStarting, setCameraStarting] = useState(false);
  const [cameraActive, setCameraActive] = useState(false);

  const [cameras, setCameras] = useState<CameraDevice[]>([]);
  const [currentCameraId, setCurrentCameraId] =
    useState<string | null>(null);

  const [torchSupported, setTorchSupported] = useState(false);
  const [torchEnabled, setTorchEnabled] = useState(false);

  const [manualMode, setManualMode] = useState(false);
  const [manualCode, setManualCode] = useState("");

  const [showAddPoints, setShowAddPoints] = useState(false);
  const [purchaseAmount, setPurchaseAmount] = useState("");
  const [customPoints, setCustomPoints] = useState("");
  const [addingPoints, setAddingPoints] = useState(false);

  const stopCamera = useCallback(async () => {
    scanningLockRef.current = true;

    try {
      controlsRef.current?.stop();
    } catch {
      // Scanner may already be stopped.
    }

    controlsRef.current = null;

    streamRef.current?.getTracks().forEach((track) => {
      track.stop();
    });

    streamRef.current = null;

    if (videoRef.current) {
      videoRef.current.pause();
      videoRef.current.srcObject = null;
    }

    if (mountedRef.current) {
      setCameraActive(false);
      setCameraStarting(false);
      setTorchEnabled(false);
      setTorchSupported(false);
    }
  }, []);

  const findMember = useCallback(
    async (rawValue: string) => {
      const memberCode = extractMemberCode(rawValue);

      if (!memberCode) {
        scanningLockRef.current = false;

        setAlert({
          type: "error",
          text: "This QR code does not contain a valid member code.",
        });

        setStatus("Invalid member code.");
        return;
      }

      scanningLockRef.current = true;
      setSearching(true);
      setMember(null);
      setAlert(null);
      setStatus("Searching member database...");

      await stopCamera();

      try {
        const { data, error } = await supabase
          .from("members")
          .select(
            `
              id,
              full_name,
              phone,
              email,
              membership_level,
              points,
              qr_code,
              is_active
            `
          )
          .eq("qr_code", memberCode)
          .maybeSingle();

        if (error) {
          throw new Error(error.message);
        }

        if (!data) {
          setStatus("Member not found.");

          setAlert({
            type: "error",
            text: `No VIVID+ member was found for code ${memberCode}.`,
          });

          return;
        }

        setMember(data as Member);

        if (data.is_active === false) {
          setStatus("Membership is inactive.");

          setAlert({
            type: "error",
            text: "This member was found, but the membership is inactive.",
          });
        } else {
          setStatus("Member verified successfully.");

          setAlert({
            type: "success",
            text: "VIVID+ member verified.",
          });
        }

        if ("vibrate" in navigator) {
          navigator.vibrate([100, 50, 100]);
        }
      } catch (error) {
        const message =
          error instanceof Error
            ? error.message
            : "Unknown database error.";

        setStatus("Member lookup failed.");

        setAlert({
          type: "error",
          text: `Member lookup failed: ${message}`,
        });
      } finally {
        setSearching(false);
      }
    },
    [stopCamera]
  );

  const loadCameraDevices = useCallback(async () => {
    if (!navigator.mediaDevices?.enumerateDevices) {
      return [];
    }

    const devices = await navigator.mediaDevices.enumerateDevices();

    const videoDevices = devices
      .filter((device) => device.kind === "videoinput")
      .map((device, index) => ({
        deviceId: device.deviceId,
        label: device.label || `Camera ${index + 1}`,
      }));

    setCameras(videoDevices);

    return videoDevices;
  }, []);

  const inspectTorchSupport = useCallback(
    (stream: MediaStream) => {
      const videoTrack = stream.getVideoTracks()[0];

      if (!videoTrack) {
        setTorchSupported(false);
        return;
      }

      const capabilities =
        typeof videoTrack.getCapabilities === "function"
          ? videoTrack.getCapabilities()
          : {};

      setTorchSupported("torch" in capabilities);
    },
    []
  );

  const beginDecoding = useCallback(
    async (stream: MediaStream) => {
      if (!videoRef.current) {
        throw new Error("Scanner video is unavailable.");
      }

      const { BrowserQRCodeReader } = await import(
        "@zxing/browser"
      );

      const reader = new BrowserQRCodeReader(undefined, {
        delayBetweenScanAttempts: 100,
        delayBetweenScanSuccess: 1000,
      });

      const controls = await reader.decodeFromStream(
        stream,
        videoRef.current,
        (result, error) => {
          if (
            result &&
            !error &&
            !scanningLockRef.current
          ) {
            scanningLockRef.current = true;
            void findMember(result.getText());
          }
        }
      );

      controlsRef.current = controls as ScannerControls;
    },
    [findMember]
  );

  const requestRearCamera = useCallback(
    async (requestedDeviceId?: string) => {
      if (!navigator.mediaDevices?.getUserMedia) {
        throw new Error(
          "Camera scanning is not supported by this browser."
        );
      }

      if (requestedDeviceId) {
        return navigator.mediaDevices.getUserMedia({
          audio: false,
          video: {
            deviceId: {
              exact: requestedDeviceId,
            },
            width: {
              ideal: 1920,
            },
            height: {
              ideal: 1080,
            },
          },
        });
      }

      /*
       * First request the environment camera as an exact requirement.
       * This prevents the phone from silently selecting the selfie camera.
       */
      try {
        return await navigator.mediaDevices.getUserMedia({
          audio: false,
          video: {
            facingMode: {
              exact: "environment",
            },
            width: {
              ideal: 1920,
            },
            height: {
              ideal: 1080,
            },
          },
        });
      } catch {
        /*
         * Some browsers do not support exact facingMode.
         * Use an environment-camera preference as the fallback.
         */
        return navigator.mediaDevices.getUserMedia({
          audio: false,
          video: {
            facingMode: {
              ideal: "environment",
            },
            width: {
              ideal: 1920,
            },
            height: {
              ideal: 1080,
            },
          },
        });
      }
    },
    []
  );

  const startCamera = useCallback(
    async (requestedDeviceId?: string) => {
      await stopCamera();

      scanningLockRef.current = false;
      setManualMode(false);
      setMember(null);
      setAlert(null);
      setCameraStarting(true);
      setStatus("Opening rear camera...");

      try {
        let selectedDeviceId = requestedDeviceId;

        if (
          !selectedDeviceId &&
          typeof window !== "undefined"
        ) {
          selectedDeviceId =
            window.localStorage.getItem(
              CAMERA_STORAGE_KEY
            ) || undefined;
        }

        let stream: MediaStream;

        try {
          stream = await requestRearCamera(selectedDeviceId);
        } catch {
          /*
           * A previously saved camera may no longer exist.
           * Retry with the physical rear-camera requirement.
           */
          stream = await requestRearCamera();
        }

        if (!mountedRef.current) {
          stream.getTracks().forEach((track) => track.stop());
          return;
        }

        streamRef.current = stream;

        const videoTrack = stream.getVideoTracks()[0];
        const activeSettings = videoTrack?.getSettings();
        const activeDeviceId =
          activeSettings?.deviceId || selectedDeviceId || null;

        setCurrentCameraId(activeDeviceId);

        if (
          activeDeviceId &&
          typeof window !== "undefined"
        ) {
          window.localStorage.setItem(
            CAMERA_STORAGE_KEY,
            activeDeviceId
          );
        }

        inspectTorchSupport(stream);

        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          videoRef.current.setAttribute(
            "playsinline",
            "true"
          );

          await videoRef.current.play();
        }

        await loadCameraDevices();
        await beginDecoding(stream);

        setCameraActive(true);
        setStatus(
          "Rear camera ready. Point it at the member QR code."
        );
      } catch (error) {
        const message =
          error instanceof Error
            ? error.message
            : String(error);

        const normalizedMessage = message.toLowerCase();

        let friendlyMessage =
          "The camera could not be opened.";

        if (
          normalizedMessage.includes("permission") ||
          normalizedMessage.includes("notallowed")
        ) {
          friendlyMessage =
            "Camera permission was denied. Allow camera access in your browser settings.";
        } else if (
          normalizedMessage.includes("notfound") ||
          normalizedMessage.includes("overconstrained")
        ) {
          friendlyMessage =
            "A rear camera could not be found on this device.";
        } else if (
          normalizedMessage.includes("notreadable") ||
          normalizedMessage.includes("could not start")
        ) {
          friendlyMessage =
            "The camera may be open in another app. Close other camera apps and retry.";
        }

        setStatus("Camera unavailable.");

        setAlert({
          type: "error",
          text: friendlyMessage,
        });

        await stopCamera();
      } finally {
        if (mountedRef.current) {
          setCameraStarting(false);
        }
      }
    },
    [
      beginDecoding,
      inspectTorchSupport,
      loadCameraDevices,
      requestRearCamera,
      stopCamera,
    ]
  );

  useEffect(() => {
    mountedRef.current = true;

    return () => {
      mountedRef.current = false;
      void stopCamera();
    };
  }, [stopCamera]);

  useEffect(() => {
    if (urlCode) {
      scanningLockRef.current = true;
      void findMember(urlCode);
      return;
    }

    void startCamera();
  }, [findMember, startCamera, urlCode]);

  async function switchCamera() {
    if (cameraStarting || cameras.length < 2) {
      return;
    }

    const currentIndex = cameras.findIndex(
      (camera) => camera.deviceId === currentCameraId
    );

    const orderedCameras = [...cameras].sort((a, b) => {
      const aRear = isRearCameraLabel(a.label) ? 0 : 1;
      const bRear = isRearCameraLabel(b.label) ? 0 : 1;

      return aRear - bRear;
    });

    const orderedCurrentIndex = orderedCameras.findIndex(
      (camera) => camera.deviceId === currentCameraId
    );

    const nextIndex =
      orderedCurrentIndex >= 0
        ? (orderedCurrentIndex + 1) %
          orderedCameras.length
        : currentIndex >= 0
          ? (currentIndex + 1) % cameras.length
          : 0;

    const nextCamera =
      orderedCameras[nextIndex] || cameras[0];

    await startCamera(nextCamera.deviceId);
  }

  async function toggleTorch() {
    const videoTrack =
      streamRef.current?.getVideoTracks()[0];

    if (!videoTrack || !torchSupported) {
      return;
    }

    const nextTorchState = !torchEnabled;

    try {
      await videoTrack.applyConstraints({
        advanced: [
          {
            torch: nextTorchState,
          } as MediaTrackConstraintSet,
        ],
      });

      setTorchEnabled(nextTorchState);
    } catch {
      setAlert({
        type: "error",
        text: "The flashlight could not be controlled on this phone.",
      });
    }
  }

  async function openManualSearch() {
    await stopCamera();

    setManualMode(true);
    setAlert(null);
    setStatus("Enter the member code manually.");
  }

  async function submitManualSearch() {
    if (!manualCode.trim()) {
      setAlert({
        type: "error",
        text: "Enter a member code first.",
      });

      return;
    }

    setManualMode(false);
    await findMember(manualCode);
  }

  async function scanAnotherMember() {
    setMember(null);
    setAlert(null);
    setManualCode("");
    setPurchaseAmount("");
    setCustomPoints("");
    setShowAddPoints(false);

    if (
      typeof window !== "undefined" &&
      window.location.search
    ) {
      window.history.replaceState({}, "", "/scanner");
    }

    await startCamera();
  }

  const automaticPoints = Math.max(
    0,
    Math.floor(Number(purchaseAmount) || 0)
  );

  const overridePoints = Math.max(
    0,
    Math.floor(Number(customPoints) || 0)
  );

  const pointsToAdd =
    overridePoints > 0 ? overridePoints : automaticPoints;

  async function addPoints() {
    if (!member || pointsToAdd <= 0) {
      setAlert({
        type: "error",
        text: "Enter a valid purchase amount or point amount.",
      });

      return;
    }

    if (member.is_active === false) {
      setAlert({
        type: "error",
        text: "Points cannot be added to an inactive membership.",
      });

      return;
    }

    setAddingPoints(true);
    setAlert(null);

    const updatedPoints =
      (member.points ?? 0) + pointsToAdd;

    try {
      const { data, error } = await supabase
        .from("members")
        .update({
          points: updatedPoints,
        })
        .eq("id", member.id)
        .select(
          `
            id,
            full_name,
            phone,
            email,
            membership_level,
            points,
            qr_code,
            is_active
          `
        )
        .single();

      if (error) {
        throw new Error(error.message);
      }

      setMember(data as Member);
      setPurchaseAmount("");
      setCustomPoints("");
      setShowAddPoints(false);

      setAlert({
        type: "success",
        text: `${pointsToAdd} points added. New balance: ${updatedPoints} points.`,
      });
    } catch (error) {
      setAlert({
        type: "error",
        text:
          error instanceof Error
            ? `Points could not be added: ${error.message}`
            : "Points could not be added.",
      });
    } finally {
      setAddingPoints(false);
    }
  }

  return (
    <main className="scanner-page">
      <div className="scanner-container">
        <header className="scanner-header">
          <div className="brand-icon">V+</div>

          <p className="eyebrow">STAFF OPERATIONS</p>

          <h1>VIVID+ Scanner</h1>

          <p className="status">{status}</p>
        </header>

        {alert && (
          <div className={`alert alert-${alert.type}`}>
            {alert.type === "success" ? (
              <CheckCircle2 size={20} />
            ) : (
              <X size={20} />
            )}

            <span>{alert.text}</span>
          </div>
        )}

        {searching && (
          <div className="loading-card">
            <Loader2 className="spin" size={24} />
            Searching member database...
          </div>
        )}

        {!member && !manualMode && !searching && (
          <>
            <section className="camera-card">
              <div className="video-wrapper">
                <video
                  ref={videoRef}
                  autoPlay
                  muted
                  playsInline
                  className="camera-video"
                />

                <div className="camera-overlay">
                  <div className="scan-frame">
                    <span className="corner corner-top-left" />
                    <span className="corner corner-top-right" />
                    <span className="corner corner-bottom-left" />
                    <span className="corner corner-bottom-right" />

                    {cameraActive && (
                      <span className="scan-line" />
                    )}
                  </div>

                  <p>Place the VIVID+ QR code inside the frame</p>
                </div>

                {cameraStarting && (
                  <div className="camera-loading">
                    <Loader2 className="spin" size={34} />
                    <strong>Opening rear camera...</strong>
                  </div>
                )}

                {!cameraActive && !cameraStarting && (
                  <div className="camera-placeholder">
                    <Camera size={38} />
                    <strong>Camera is not active</strong>
                  </div>
                )}
              </div>
            </section>

            <div className="camera-actions">
              {torchSupported && (
                <button
                  type="button"
                  onClick={() => void toggleTorch()}
                  className={
                    torchEnabled
                      ? "action-button active-button"
                      : "action-button"
                  }
                >
                  <Flashlight size={20} />
                  {torchEnabled ? "Flash on" : "Flash"}
                </button>
              )}

              {cameras.length > 1 && (
                <button
                  type="button"
                  disabled={cameraStarting}
                  onClick={() => void switchCamera()}
                  className="action-button"
                >
                  <SwitchCamera size={20} />
                  Switch
                </button>
              )}

              <button
                type="button"
                onClick={() => void openManualSearch()}
                className="action-button"
              >
                <Search size={20} />
                Manual
              </button>
            </div>

            {!cameraActive && !cameraStarting && (
              <button
                type="button"
                onClick={() => void startCamera()}
                className="primary-button"
              >
                <RefreshCw size={20} />
                Retry rear camera
              </button>
            )}
          </>
        )}

        {manualMode && !member && !searching && (
          <section className="panel">
            <button
              type="button"
              onClick={() => void startCamera()}
              className="back-button"
            >
              <ChevronLeft size={18} />
              Back to camera
            </button>

            <label htmlFor="member-code">
              MEMBER CODE
            </label>

            <input
              id="member-code"
              value={manualCode}
              onChange={(event) =>
                setManualCode(event.target.value)
              }
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  void submitManualSearch();
                }
              }}
              placeholder="Example: VIVID-123456"
              autoComplete="off"
              autoCapitalize="characters"
            />

            <button
              type="button"
              onClick={() => void submitManualSearch()}
              className="primary-button"
            >
              <Search size={20} />
              Find member
            </button>
          </section>
        )}

        {member && (
          <section className="member-card">
            <div
              className={
                member.is_active === false
                  ? "verification inactive"
                  : "verification active"
              }
            >
              {member.is_active === false
                ? "MEMBERSHIP INACTIVE"
                : "MEMBER VERIFIED"}
            </div>

            <div className="member-content">
              <div className="member-heading">
                <div className="member-avatar">
                  <UserRound size={29} />
                </div>

                <div>
                  <p className="eyebrow">
                    VIVID+ MEMBER
                  </p>

                  <h2>
                    {member.full_name || "VIVID+ Member"}
                  </h2>

                  <p className="muted">
                    {member.membership_level || "Member"}{" "}
                    membership
                  </p>
                </div>
              </div>

              <div className="points-balance">
                <span>AVAILABLE BALANCE</span>
                <strong>{member.points ?? 0}</strong>
                <p>points</p>
              </div>

              <button
                type="button"
                disabled={member.is_active === false}
                onClick={() => setShowAddPoints(true)}
                className="primary-button"
              >
                <Plus size={20} />
                Add points
              </button>

              <div className="member-details">
                <MemberDetail
                  label="Status"
                  value={
                    member.is_active === false
                      ? "Inactive"
                      : "Active"
                  }
                />

                <MemberDetail
                  label="Phone"
                  value={member.phone || "Not provided"}
                />

                <MemberDetail
                  label="Email"
                  value={member.email || "Not provided"}
                />

                <MemberDetail
                  label="Member code"
                  value={member.qr_code || "Not available"}
                />
              </div>

              <button
                type="button"
                onClick={() => void scanAnotherMember()}
                className="secondary-button"
              >
                <QrCode size={20} />
                Scan another member
              </button>
            </div>
          </section>
        )}
      </div>

      {showAddPoints && member && (
        <div className="modal-background">
          <section className="modal">
            <button
              type="button"
              aria-label="Close"
              disabled={addingPoints}
              onClick={() => setShowAddPoints(false)}
              className="close-button"
            >
              <X size={20} />
            </button>

            <p className="eyebrow">STAFF ACTION</p>
            <h2>Add loyalty points</h2>

            <p className="muted">
              Adding points for{" "}
              <strong>
                {member.full_name || "VIVID+ Member"}
              </strong>
            </p>

            <label htmlFor="purchase-amount">
              PURCHASE AMOUNT
            </label>

            <div className="money-input">
              <CircleDollarSign size={20} />

              <input
                id="purchase-amount"
                type="number"
                min="0"
                step="0.01"
                inputMode="decimal"
                value={purchaseAmount}
                onChange={(event) =>
                  setPurchaseAmount(event.target.value)
                }
                placeholder="0.00"
              />
            </div>

            <p className="input-help">
              One point is added for each dollar spent.
            </p>

            <label htmlFor="custom-points">
              CUSTOM POINTS OVERRIDE
            </label>

            <input
              id="custom-points"
              type="number"
              min="0"
              step="1"
              inputMode="numeric"
              value={customPoints}
              onChange={(event) =>
                setCustomPoints(event.target.value)
              }
              placeholder="Optional"
            />

            <div className="new-balance">
              <div>
                <span>NEW BALANCE</span>

                <strong>
                  {(member.points ?? 0) + pointsToAdd} points
                </strong>
              </div>

              <b>+{pointsToAdd}</b>
            </div>

            <button
              type="button"
              disabled={addingPoints || pointsToAdd <= 0}
              onClick={() => void addPoints()}
              className="primary-button"
            >
              {addingPoints ? (
                <>
                  <Loader2 className="spin" size={20} />
                  Adding points...
                </>
              ) : (
                <>
                  <Plus size={20} />
                  Confirm {pointsToAdd} points
                </>
              )}
            </button>
          </section>
        </div>
      )}

      <style jsx global>{`
        * {
          box-sizing: border-box;
        }

        body {
          margin: 0;
          background: #050505;
        }

        button,
        input {
          font: inherit;
        }

        button {
          touch-action: manipulation;
        }

        .scanner-page {
          min-height: 100vh;
          padding: 28px 18px 50px;
          background:
            radial-gradient(
              circle at top,
              #291907 0%,
              #0d0d0d 38%,
              #050505 100%
            );
          color: white;
          font-family: Arial, Helvetica, sans-serif;
        }

        .scanner-container {
          width: 100%;
          max-width: 520px;
          margin: 0 auto;
        }

        .scanner-header {
          margin-bottom: 22px;
          text-align: center;
        }

        .brand-icon {
          width: 56px;
          height: 56px;
          display: grid;
          place-items: center;
          margin: 0 auto 14px;
          border: 1px solid #f5a623;
          border-radius: 17px;
          background: rgba(245, 166, 35, 0.12);
          color: #f5a623;
          font-size: 22px;
          font-weight: 900;
        }

        .eyebrow {
          margin: 0 0 6px;
          color: #f5a623;
          font-size: 12px;
          font-weight: 900;
          letter-spacing: 0.13em;
        }

        h1 {
          margin: 0;
          font-size: 30px;
        }

        .status,
        .muted {
          color: #aaa;
        }

        .status {
          margin: 9px 0 0;
          font-size: 14px;
          line-height: 1.5;
        }

        .alert {
          display: flex;
          align-items: flex-start;
          gap: 10px;
          margin-bottom: 16px;
          padding: 14px;
          border-radius: 14px;
          font-size: 14px;
          font-weight: 700;
          line-height: 1.45;
        }

        .alert-success {
          border: 1px solid rgba(74, 222, 128, 0.45);
          background: rgba(34, 197, 94, 0.12);
          color: #4ade80;
        }

        .alert-error {
          border: 1px solid rgba(248, 113, 113, 0.45);
          background: rgba(220, 38, 38, 0.12);
          color: #f87171;
        }

        .alert-info {
          border: 1px solid rgba(96, 165, 250, 0.45);
          background: rgba(59, 130, 246, 0.12);
          color: #60a5fa;
        }

        .loading-card {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 10px;
          padding: 24px;
          border: 1px solid #f5a623;
          border-radius: 18px;
          background: #171717;
          color: #f5a623;
          font-weight: 800;
        }

        .camera-card {
          padding: 10px;
          border: 1px solid rgba(245, 166, 35, 0.55);
          border-radius: 24px;
          background: #171717;
          box-shadow: 0 25px 80px rgba(0, 0, 0, 0.45);
        }

        .video-wrapper {
          position: relative;
          min-height: 420px;
          overflow: hidden;
          border-radius: 17px;
          background: black;
        }

        .camera-video {
          position: absolute;
          width: 100%;
          height: 100%;
          min-height: 420px;
          object-fit: cover;
        }

        .camera-overlay {
          position: absolute;
          inset: 0;
          z-index: 2;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          pointer-events: none;
          background: radial-gradient(
            circle,
            transparent 0%,
            transparent 35%,
            rgba(0, 0, 0, 0.28) 75%
          );
        }

        .camera-overlay p {
          position: absolute;
          bottom: 18px;
          margin: 0;
          padding: 9px 13px;
          border-radius: 999px;
          background: rgba(0, 0, 0, 0.7);
          font-size: 12px;
          font-weight: 800;
        }

        .scan-frame {
          position: relative;
          width: min(70vw, 270px);
          height: min(70vw, 270px);
        }

        .corner {
          position: absolute;
          width: 42px;
          height: 42px;
          border-color: #f5a623;
          border-style: solid;
        }

        .corner-top-left {
          top: 0;
          left: 0;
          border-width: 4px 0 0 4px;
          border-radius: 12px 0 0;
        }

        .corner-top-right {
          top: 0;
          right: 0;
          border-width: 4px 4px 0 0;
          border-radius: 0 12px 0 0;
        }

        .corner-bottom-left {
          bottom: 0;
          left: 0;
          border-width: 0 0 4px 4px;
          border-radius: 0 0 0 12px;
        }

        .corner-bottom-right {
          right: 0;
          bottom: 0;
          border-width: 0 4px 4px 0;
          border-radius: 0 0 12px;
        }

        .scan-line {
          position: absolute;
          top: 10px;
          left: 10px;
          right: 10px;
          height: 2px;
          background: #f5a623;
          box-shadow: 0 0 14px #f5a623;
          animation: scan-line-animation 2s linear infinite;
        }

        .camera-loading,
        .camera-placeholder {
          position: absolute;
          inset: 0;
          z-index: 5;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          gap: 12px;
          background: rgba(5, 5, 5, 0.9);
          color: #f5a623;
        }

        .camera-actions {
          display: grid;
          grid-template-columns: repeat(
            auto-fit,
            minmax(100px, 1fr)
          );
          gap: 10px;
          margin-top: 13px;
        }

        .action-button,
        .secondary-button,
        .primary-button {
          min-height: 54px;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          border-radius: 14px;
          font-weight: 900;
          cursor: pointer;
        }

        .action-button,
        .secondary-button {
          border: 1px solid rgba(255, 255, 255, 0.15);
          background: #171717;
          color: white;
        }

        .active-button {
          border-color: #f5a623;
          background: rgba(245, 166, 35, 0.15);
          color: #f5a623;
        }

        .primary-button {
          width: 100%;
          margin-top: 14px;
          border: 0;
          background: #f5a623;
          color: #111;
        }

        .primary-button:disabled {
          cursor: not-allowed;
          opacity: 0.48;
        }

        .panel,
        .modal {
          padding: 22px;
          border: 1px solid rgba(245, 166, 35, 0.55);
          border-radius: 21px;
          background: #171717;
        }

        .back-button {
          display: flex;
          align-items: center;
          gap: 4px;
          margin-bottom: 20px;
          padding: 0;
          border: 0;
          background: transparent;
          color: #bbb;
          font-weight: 800;
          cursor: pointer;
        }

        label {
          display: block;
          margin: 18px 0 8px;
          color: #ddd;
          font-size: 13px;
          font-weight: 900;
          letter-spacing: 0.05em;
        }

        input {
          width: 100%;
          min-height: 52px;
          padding: 0 14px;
          border: 1px solid rgba(255, 255, 255, 0.15);
          border-radius: 12px;
          outline: none;
          background: #0d0d0d;
          color: white;
          font-size: 16px;
          font-weight: 700;
        }

        input:focus {
          border-color: #f5a623;
        }

        .member-card {
          overflow: hidden;
          border: 1px solid #f5a623;
          border-radius: 23px;
          background: linear-gradient(
            145deg,
            #20160c,
            #171717 45%,
            #101010
          );
        }

        .verification {
          padding: 15px;
          text-align: center;
          font-weight: 900;
          letter-spacing: 0.05em;
        }

        .verification.active {
          background: rgba(34, 197, 94, 0.14);
          color: #4ade80;
        }

        .verification.inactive {
          background: rgba(220, 38, 38, 0.15);
          color: #f87171;
        }

        .member-content {
          padding: 23px;
        }

        .member-heading {
          display: flex;
          align-items: center;
          gap: 14px;
        }

        .member-avatar {
          width: 58px;
          height: 58px;
          display: grid;
          place-items: center;
          flex-shrink: 0;
          border: 1px solid rgba(245, 166, 35, 0.5);
          border-radius: 18px;
          background: rgba(245, 166, 35, 0.12);
          color: #f5a623;
        }

        .member-heading h2 {
          margin: 0;
          font-size: 24px;
        }

        .member-heading .muted {
          margin: 6px 0 0;
          font-size: 14px;
        }

        .points-balance {
          margin-top: 21px;
          padding: 20px;
          border: 1px solid rgba(245, 166, 35, 0.3);
          border-radius: 18px;
          background: rgba(245, 166, 35, 0.08);
          text-align: center;
        }

        .points-balance span,
        .new-balance span {
          display: block;
          color: #aaa;
          font-size: 12px;
          font-weight: 900;
          letter-spacing: 0.08em;
        }

        .points-balance strong {
          display: block;
          margin-top: 5px;
          color: #f5a623;
          font-size: 43px;
        }

        .points-balance p {
          margin: 3px 0 0;
          font-weight: 800;
        }

        .member-details {
          margin-top: 20px;
          border-top: 1px solid rgba(255, 255, 255, 0.1);
        }

        .member-detail {
          display: flex;
          justify-content: space-between;
          gap: 18px;
          padding: 14px 0;
          border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        }

        .member-detail span {
          color: #999;
          font-size: 14px;
          font-weight: 700;
        }

        .member-detail strong {
          max-width: 65%;
          text-align: right;
          overflow-wrap: anywhere;
          font-size: 14px;
        }

        .secondary-button {
          width: 100%;
          margin-top: 20px;
        }

        .modal-background {
          position: fixed;
          inset: 0;
          z-index: 999;
          display: flex;
          align-items: flex-end;
          justify-content: center;
          padding: 18px;
          background: rgba(0, 0, 0, 0.83);
          backdrop-filter: blur(8px);
        }

        .modal {
          position: relative;
          width: 100%;
          max-width: 500px;
          box-shadow: 0 30px 100px rgba(0, 0, 0, 0.65);
        }

        .modal h2 {
          margin: 0 40px 6px 0;
        }

        .close-button {
          position: absolute;
          top: 14px;
          right: 14px;
          width: 38px;
          height: 38px;
          display: grid;
          place-items: center;
          border: 1px solid rgba(255, 255, 255, 0.15);
          border-radius: 50%;
          background: #242424;
          color: white;
          cursor: pointer;
        }

        .money-input {
          position: relative;
        }

        .money-input svg {
          position: absolute;
          top: 16px;
          left: 14px;
          color: #f5a623;
        }

        .money-input input {
          padding-left: 44px;
        }

        .input-help {
          margin: 8px 0 18px;
          color: #888;
          font-size: 12px;
        }

        .new-balance {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
          margin-top: 20px;
          padding: 16px;
          border: 1px solid rgba(245, 166, 35, 0.3);
          border-radius: 14px;
          background: rgba(245, 166, 35, 0.08);
        }

        .new-balance strong {
          display: block;
          margin-top: 4px;
        }

        .new-balance b {
          color: #f5a623;
          font-size: 24px;
        }

        .spin {
          animation: spin-animation 1s linear infinite;
        }

        @keyframes spin-animation {
          to {
            transform: rotate(360deg);
          }
        }

        @keyframes scan-line-animation {
          0% {
            top: 10px;
          }

          50% {
            top: calc(100% - 12px);
          }

          100% {
            top: 10px;
          }
        }

        @media (max-width: 420px) {
          .video-wrapper,
          .camera-video {
            min-height: 390px;
          }
        }
      `}</style>
    </main>
  );
}

function MemberDetail({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="member-detail">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export default function ScannerPage() {
  return (
    <Suspense
      fallback={
        <main
          style={{
            minHeight: "100vh",
            display: "grid",
            placeItems: "center",
            background: "#050505",
            color: "#f5a623",
            fontFamily: "Arial, Helvetica, sans-serif",
            fontWeight: 900,
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