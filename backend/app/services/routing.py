import osmnx as ox
import networkx as nx
from typing import List

_graph = None

def get_graph():
    global _graph
    if _graph is None:
        _graph = ox.graph_from_place("Bogota, Colombia", network_type="drive")
    return _graph

def compute_routes(origin_lat: float, origin_lon: float, n_routes: int = 3) -> List[dict]:
    G = get_graph()
    origin_node = ox.distance.nearest_nodes(G, origin_lon, origin_lat)
    candidates = list(G.successors(origin_node))
    if not candidates:
        return []
    # Penalización simple: rutas más largas y con más intersecciones bajan score
    routes = []
    for i, target in enumerate(candidates[:max(n_routes * 3, 9)]):
        try:
            path = nx.shortest_path(G, origin_node, target, weight="length")
        except nx.NetworkXNoPath:
            continue
        length = sum(G[u][v][0].get("length", 0) for u, v in zip(path[:-1], path[1:]))
        score = 1.0 / (1.0 + length / 1000.0)
        geometry = [[G.nodes[n]["y"], G.nodes[n]["x"]] for n in path]
        routes.append({
            "route_id": i,
            "score": round(score, 4),
            "distance_m": round(length, 1),
            "geometry": geometry,
            "penalized_cai": False,
            "penalized_congestion": False,
        })
    routes.sort(key=lambda r: r["score"], reverse=True)
    return routes[:n_routes]