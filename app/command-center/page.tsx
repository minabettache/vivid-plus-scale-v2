async function getDashboard() {
  const res = await fetch("http://localhost:3000/api/v1/command-center?period=today", {
    cache: "no-store",
  });

  if (!res.ok) {
    throw new Error("Failed to load dashboard");
  }

  return res.json();
}

export default async function CommandCenter() {
  const data = await getDashboard();

  return (
    <main
      style={{
        padding: 40,
        background: "#0F1115",
        minHeight: "100vh",
        color: "white",
      }}
    >
      <h1>Executive Command Center</h1>

      <h2 style={{ marginTop: 30 }}>
        Business Health: {data.businessHealth.score}/100
      </h2>

      <p>{data.businessHealth.status}</p>

      <hr />

      <h2>Executive Brief</h2>

      <p>{data.aiBrief.summary}</p>

      <hr />

      <h2>Today's Priorities</h2>

      <ul>
        {data.priorities.map((item: any) => (
          <li key={item.id}>
            <strong>{item.title}</strong>
            <br />
            {item.description}
          </li>
        ))}
      </ul>
    </main>
  );
}