"use client";

import {
  CakeSlice,
  CupSoda,
  LoaderCircle,
  Ticket,
} from "lucide-react";
import { useEffect, useState } from "react";

import { supabase } from "@/lib/supabase";

type DatabaseReward = {
  id: number;
  name: string;
  description: string | null;
  points_required: number;
  minimum_spend: number | null;
  age_restricted: boolean;
  minimum_age: number | null;
  is_active: boolean;
};

type RedemptionResult = {
  success?: boolean;
  redemption_id?: number;
  reward_name?: string;
  points_spent?: number;
  remaining_points?: number;
};

type RewardsPanelProps = {
  memberId: number;
  points: number;
  onPointsChange: (newPoints: number) => void;
};

function getRewardIcon(name: string) {
  const normalizedName = name.toLowerCase();

  if (normalizedName.includes("drink")) {
    return CupSoda;
  }

  if (normalizedName.includes("birthday")) {
    return CakeSlice;
  }

  return Ticket;
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  if (
    typeof error === "object" &&
    error !== null &&
    "message" in error &&
    typeof error.message === "string"
  ) {
    return error.message;
  }

  return "An unexpected error occurred.";
}

export function RewardsPanel({
  memberId,
  points,
  onPointsChange,
}: RewardsPanelProps) {
  const [rewards, setRewards] = useState<DatabaseReward[]>(
    []
  );
  const [loading, setLoading] = useState(true);
  const [redeemingId, setRedeemingId] =
    useState<number | null>(null);
  const [message, setMessage] = useState("");
  const [messageType, setMessageType] = useState<
    "success" | "error" | ""
  >("");

  useEffect(() => {
    let active = true;

    async function loadRewards() {
      setLoading(true);
      setMessage("");
      setMessageType("");

      try {
        const { data, error } = await supabase
          .from("rewards")
          .select(
            "id, name, description, points_required, minimum_spend, age_restricted, minimum_age, is_active"
          )
          .eq("is_active", true)
          .order("points_required", {
            ascending: true,
          });

        if (error) {
          throw error;
        }

        if (!active) {
          return;
        }

        const rewardRows =
          (data ?? []) as unknown as DatabaseReward[];

        setRewards(rewardRows);
      } catch (error) {
        console.error(
          "Failed to load rewards:",
          error
        );

        if (active) {
          setRewards([]);
          setMessage(
            "Unable to load rewards right now."
          );
          setMessageType("error");
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    }

    void loadRewards();

    return () => {
      active = false;
    };
  }, []);

  async function redeemReward(
    reward: DatabaseReward
  ) {
    if (redeemingId !== null) {
      return;
    }

    if (
      !Number.isInteger(memberId) ||
      memberId <= 0
    ) {
      setMessage(
        "Your member account could not be identified. Please contact staff."
      );
      setMessageType("error");
      return;
    }

    if (points < reward.points_required) {
      const pointsNeeded =
        reward.points_required - points;

      setMessage(
        `You need ${pointsNeeded} more points to redeem this reward.`
      );
      setMessageType("error");
      return;
    }

    const confirmed = window.confirm(
      `Redeem "${reward.name}" for ${reward.points_required} points?`
    );

    if (!confirmed) {
      return;
    }

    setRedeemingId(reward.id);
    setMessage("");
    setMessageType("");

    try {
      const { data, error } = await supabase.rpc(
        "redeem_reward",
        {
          p_member_id: memberId,
          p_reward_id: reward.id,
        }
      );

      if (error) {
        throw error;
      }

      const result =
        data as unknown as RedemptionResult | null;

      if (
        !result ||
        typeof result.remaining_points !== "number"
      ) {
        throw new Error(
          "The reward was processed, but the updated points balance was not returned."
        );
      }

      onPointsChange(result.remaining_points);

      setMessage(
        `${
          result.reward_name ?? reward.name
        } redeemed successfully. Show your digital membership card to VIVID+ staff.`
      );
      setMessageType("success");
    } catch (error) {
      console.error(
        "Redemption failed:",
        error
      );

      const errorMessage =
        getErrorMessage(error);
      const normalizedError =
        errorMessage.toLowerCase();

      if (
        normalizedError.includes(
          "not enough points"
        )
      ) {
        setMessage(
          "You do not have enough points for this reward."
        );
      } else if (
        normalizedError.includes(
          "active member not found"
        )
      ) {
        setMessage(
          "Your active membership could not be found."
        );
      } else if (
        normalizedError.includes(
          "reward is not available"
        )
      ) {
        setMessage(
          "This reward is no longer available."
        );
      } else {
        setMessage(
          errorMessage || "Redemption failed."
        );
      }

      setMessageType("error");
    } finally {
      setRedeemingId(null);
    }
  }

  return (
    <section className="section page-section">
      <div className="section-head">
        <div>
          <p className="eyebrow small">
            REDEEM YOUR POINTS
          </p>

          <h3>Reward Store</h3>
        </div>

        <span>{points} Points</span>
      </div>

      {message && (
        <p
          role="status"
          aria-live="polite"
          style={{
            marginBottom: "16px",
            padding: "12px",
            borderRadius: "12px",
            border:
              messageType === "success"
                ? "1px solid rgba(34, 197, 94, 0.35)"
                : "1px solid rgba(245, 166, 35, 0.35)",
            background:
              messageType === "success"
                ? "rgba(34, 197, 94, 0.12)"
                : "rgba(245, 166, 35, 0.12)",
            color:
              messageType === "success"
                ? "#4ade80"
                : "inherit",
          }}
        >
          {message}
        </p>
      )}

      {loading ? (
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "8px",
          }}
        >
          <LoaderCircle
            size={18}
            aria-hidden="true"
          />

          <p style={{ margin: 0 }}>
            Loading rewards...
          </p>
        </div>
      ) : rewards.length === 0 ? (
        <p>
          No rewards are available right now.
        </p>
      ) : (
        <div className="reward-list">
          {rewards.map((reward) => {
            const Icon = getRewardIcon(
              reward.name
            );

            const unlocked =
              points >= reward.points_required;

            const isRedeeming =
              redeemingId === reward.id;

            const pointsNeeded = Math.max(
              reward.points_required - points,
              0
            );

            return (
              <article
                key={reward.id}
                className={`reward-card ${
                  unlocked
                    ? "reward-active"
                    : "reward-locked"
                }`}
              >
                <div className="reward-icon">
                  <Icon
                    size={26}
                    aria-hidden="true"
                  />
                </div>

                <div className="reward-content">
                  <h4>{reward.name}</h4>

                  <p>
                    {reward.description ||
                      "Eligible VIVID+ member reward"}
                  </p>

                  {Number(
                    reward.minimum_spend ?? 0
                  ) > 0 && (
                    <small
                      style={{
                        display: "block",
                        marginTop: "6px",
                      }}
                    >
                      Minimum purchase: $
                      {Number(
                        reward.minimum_spend
                      ).toFixed(2)}
                    </small>
                  )}

                  {reward.age_restricted && (
                    <small
                      style={{
                        display: "block",
                        marginTop: "4px",
                      }}
                    >
                      Valid physical ID required
                      {Number(
                        reward.minimum_age ?? 0
                      ) > 0
                        ? ` · ${reward.minimum_age}+`
                        : ""}
                    </small>
                  )}

                  {!unlocked && (
                    <small
                      style={{
                        display: "block",
                        marginTop: "4px",
                      }}
                    >
                      Earn {pointsNeeded} more
                      points
                    </small>
                  )}

                  <div className="reward-footer">
                    <strong>
                      {reward.points_required}{" "}
                      Points
                    </strong>

                    <button
                      type="button"
                      className={
                        unlocked
                          ? "reward-button"
                          : "reward-button disabled"
                      }
                      disabled={
                        !unlocked ||
                        redeemingId !== null
                      }
                      onClick={() =>
                        void redeemReward(reward)
                      }
                    >
                      {isRedeeming
                        ? "Redeeming..."
                        : unlocked
                          ? "Redeem"
                          : "Locked"}
                    </button>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </section>
  );
}