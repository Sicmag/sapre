import { useState } from "react";

const API = "https://api-demo.sapre.com";

export default function App() {
  const [plate, setPlate] = useState("");
  const [nexos, setNexos] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function consultar() {
    setError("");
    setNexos(null);
    if (!plate.trim()) return;
    setLoading(true);
    try {
      const r = await fetch(${API}/api/v1/graph/nexos/);
      if (!r.ok) throw new Error("Sin nexos registrados para esta placa");
      setNexos(await r.json());
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ fontFamily: "sans-serif", padding: 24, maxWidth: 900, margin: "auto" }}>
      <h1>SAPRE â€” Fase 1</h1>
      <p style={{ color: "#666" }}>
        AnalÃ­tica de vigilancia con revisiÃ³n humana obligatoria. Sin facial. Sin operaciones encubiertas.
      </p>

      <div style={{ display: "flex", gap: 8, margin: "16px 0" }}>
        <input
          value={plate}
          onChange={(e) => setPlate(e.target.value)}
          placeholder="Placa (ej: ABC123)"
          style={{ padding: 8, flex: 1, textTransform: "uppercase" }}
        />
        <button onClick={consultar} disabled={loading} style={{ padding: "8px 16px" }}>
          {loading ? "Consultando..." : "Consultar nexos"}
        </button>
      </div>

      {error && <p style={{ color: "crimson" }}>{error}</p>}

      {nexos && (
        <div>
          <h2>Nexos para {nexos.plate}</h2>
          <ul>
            {nexos.nodes.map((n) => (
              <li key={n.id}>
                <strong>{n.type}</strong>: {n.label} â€” base legal: {n.legal_basis}
              </li>
            ))}
          </ul>
        </div>
      )}

      <footer style={{ marginTop: 32, fontSize: 12, color: "#888" }}>
        Cada consulta queda registrada en auditorÃ­a inmutable. RevisiÃ³n humana obligatoria antes de cualquier acciÃ³n.
      </footer>
    </div>
  );
}
