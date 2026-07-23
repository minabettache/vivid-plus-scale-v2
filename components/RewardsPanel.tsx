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

export function RewardsPanel({
  memberId,
  points,
  onPointsChange,
}: RewardsPanelProps) {
  const [rewards, setRewards] = useState<DatabaseReward[]>([]);
  const [loading, setLoading] = useState(true);
  const [redeemingId, setRedeemingId] = useState<number | null>(
    null
  );
  const [message, setMessage] = useState("");

  useEffect(() => {
    async function loadRewards() {
      const { data, error } = await supabase
        .from("rewards")
        .select(
          "id, name, description, points_required, minimum_spend, age_restricted, minimum_age, is_active"
        )
        .eq("is_active", true)
        .order("points_required", { ascending: true });

      if (error) {
        console.error("Failed to load rewards:", error);
        setMessage("Unable to load rewards.");
      } else {
        setRewards((data ?? []) as DatabaseReward[]);
      }

      setLoading(false);
    }

    void loadRewards();
  }, []);

  async function redeemReward(reward: DatabaseReward) {
    if (redeemingId !== null) {
      return;
    }

    if (points < reward.points_required) {
      setMessage("You do not have enough points.");
      return;
    }

    const confirmed = window.confirm(
      `Redeem ${reward.name} for ${reward.points_required} points?`
    );

    if (!confirmed) {
      return;
    }

    setRedeemingId(reward.id);
    setMessage("");

    const { data, error } = await supabase.rpc("redeem_reward", {
      p_member_id: memberId,
      p_reward_id: reward.id,
    });

    if (error) {
      console.error("Redemption failed:", error);
      setMessage(error.message || "Redemption failed.");
      setRedeemingId(null);
      return;
    }

    const result = data as {
      remaining_points?: number;
      reward_name?: string;
    };

    onPointsChange(Number(result.remaining_points ?? points));
    setMessage(
      `${result.reward_name ?? reward.name} redeemed successfully. Show your membership card to staff.`
    );
    setRedeemingId(null);
  }

  return (
    <section className="section page-section">
      <div className="section-head">
        <div>
          <p className="eyebrow small">REDEEM YOUR POINTS</p>
          <h3>Reward Store</h3>
        </div>

        <span>{points} Points</span>
      </div>

      {message && (
        <p
          role="status"
          style={{
            marginBottom: "16px",
            padding: "12px",
            borderRadius: "12px",
            background: "rgba(245, 166, 35, 0.12)",
          }}
        >
          {message}
        </p>
      )}

      {loading ? (
        <p>
          <LoaderCircle
            size={18}
            style={{ verticalAlign: "middle" }}
          />{" "}
          Loading rewards...
        </p>
      ) : (
        <div className="reward-list">
          {rewards.map((reward) => {
            const Icon = getRewardIcon(reward.name);
            const unlocked =
              points >= reward.points_required;
            const isRedeeming =
              redeemingId === reward.id;

            return (
              <article
                className={`reward-card ${
                  unlocked
                    ? "reward-active"
                    : "reward-locked"
                }`}
                key={reward.id}
              >
                <div className="reward-icon">
                  <Icon size={26} />
                </div>

                <div className="reward-content">
                  <h4>{reward.name}</h4>

                  <p>
                    {reward.description ||
                      "Eligible VIVID+ member reward"}
                  </p>

                  {Number(reward.minimum_spend ?? 0) > 0 && (
                    <small>
                      Minimum purchase: $
                      {Number(
                        reward.minimum_spend
                      ).toFixed(2)}
                    </small>
                  )}

                  <div className="reward-footer">
                    <strong>
                      {reward.points_required} Points
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