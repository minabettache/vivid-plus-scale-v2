export async function getCommandCenter() {
  const res = await fetch("http://localhost:3000/api/v1/command-center", {
    cache: "no-store",
  });

  if (!res.ok) throw new Error("Failed to load dashboard");

  return res.json();
}