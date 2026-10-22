// Pure functions shared by QML and the local transition tests.
function normalize(page) {
    if (page === "home") return "audio";
    return ["wifi", "bluetooth", "audio", "mixer", "brightness", "clipboard", "displays"].indexOf(page) >= 0 ? page : "audio";
}
function toggle(current, requested) {
    requested = normalize(requested);
    if (requested === current || (current === "mixer" && requested === "audio")) return "";
    return requested;
}
function barEdges(layers) {
    if (!layers || typeof layers !== "object" || Array.isArray(layers)) throw new Error("Invalid layers response");
    const result = {};
    for (const name of Object.keys(layers)) {
        let bottom = 0;
        for (const level of Object.values(layers[name].levels || {})) {
            for (const surface of level) {
                // Hyprland 0.56.2 reports monitor-local logical coordinates.
                if (surface.namespace === "waybar" && Number.isFinite(surface.y) && Number.isFinite(surface.h) && surface.y >= 0 && surface.h > 0)
                    bottom = Math.max(bottom, surface.y + surface.h);
            }
        }
        result[name] = bottom;
    }
    return result;
}
function displayMode(displays, reference) {
    if (displays.length !== 2) return "configure";
    const first = displays.find(d => d.id === reference);
    const other = displays.find(d => d.id !== reference);
    if (!first || !other) return "configure";
    if (first.disabled && !other.disabled) return "other";
    if (!first.disabled && other.disabled) return "only";
    if ((first.hyprId !== undefined && other.mirrorOf === String(first.hyprId)) ||
        (other.hyprId !== undefined && first.mirrorOf === String(other.hyprId))) return "mirror";
    if (!first.disabled && !other.disabled && first.y === other.y) {
        if (other.x > first.x) return "right";
        if (other.x < first.x) return "left";
    }
    return "configure";
}
