import { useState } from "react";

// URL temporal de API (Simulada para la demo)
const API = "https://api-demo.sapre.com";

export default function App() {
  const [plate, setPlate] = useState("");
  const [nexos, setNexos] = useState(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  // Función que simula la respuesta del backend
  async function consultar() {
    setError("");
    setNexos(null);
    if (!plate.trim()) return;
    setLoading(true);
    
    // Simulamos un tiempo de espera de 1.5 segundos
    setTimeout(() => {
      setNexos({
        plate: plate.trim().toUpperCase(),
        nodes: [
          { id: "1", type: "Vehículo", label: "Registrado a nombre de Carlos M.", legal_basis: "Ley 1581" },
          { id: "2", type: "Alerta", label: "Asociado a banda 'Los del Sur'", legal_basis: "Convenio Fiscalía" },
          { id: "3", type: "Ubicación", label: "Visto por última vez en CAI Kennedy", legal_basis: "Cámara Pública" }
        ]
      });
      setLoading(false);
    }, 1500);
  }

  return (
    <div style={{ fontFamily: "sans-serif", padding: 24, maxWidth: 900, margin: "auto" }}>
      <h1>SAPRE — Fase 1</h1>
      <p style={{ color: "#666" }}>
        Analítica de vigilancia con revisión humana obligatoria. Sin facial. Sin operaciones encubiertas.
      </p>

      <div style={{ display: "flex", gap: 8, margin: "16px 0" }}>
        <input
          value={plate}
          onChange={(e) => setPlate(e.target.value)}
          placeholder="Placa (ej: ABC123)"
          style={{ padding: 8, flex: 1, textTransform: "uppercase", border: "1px solid #ccc", borderRadius: "4px" }}
        />
        <button onClick={consultar} disabled={loading} style={{ padding: "8px 16px", cursor: "pointer", background: "#007bff", color: "#fff", border: "none", borderRadius: "4px" }}>
          {loading ? "Consultando..." : "Consultar nexos"}
        </button>
      </div>

      {error && <p style={{ color: "crimson" }}>{error}</p>}

      {nexos && (
        <div style={{ border: "1px solid #ddd", padding: "16px", borderRadius: "8px", background: "#f9f9f9" }}>
          <h2 style={{ color: "#333" }}>Nexos para {nexos.plate}</h2>
          <ul style={{ listStyleType: "none", padding: 0 }}>
            {nexos.nodes.map((n) => (
              <li key={n.id} style={{ marginBottom: "8px", padding: "8px", background: "#fff", borderLeft: "4px solid #007bff" }}>
                <strong>{n.type}</strong>: {n.label} <br />
                <span style={{ fontSize: "12px", color: "#888" }}>Base legal: {n.legal_basis}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <footer style={{ marginTop: 32, fontSize: 12, color: "#888" }}>
        Cada consulta queda registrada en auditoría inmutable. Revisión humana obligatoria antes de cualquier acción.
      </footer>
    </div>
  );
}