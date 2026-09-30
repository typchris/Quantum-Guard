const MANIFESTS = new Map([
  [
    "/updates/latest.json",
    "https://raw.githubusercontent.com/typchris/Quantum-Guard/main/releases/latest.json",
  ],
  [
    "/updates/latest-stable.json",
    "https://raw.githubusercontent.com/typchris/Quantum-Guard/main/releases/latest-stable.json",
  ],
]);

const DOWNLOAD_PREFIX =
  "https://github.com/typchris/Quantum-Guard/releases/download/";
const RELEASE_PREFIX =
  "https://github.com/typchris/Quantum-Guard/releases/tag/";
const MAX_UPDATE_BYTES = 256 * 1024 * 1024;
const VERSION_RE =
  /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;

function jsonResponse(body, status = 200, cacheControl = "no-store") {
  return new Response(JSON.stringify(body, null, 2) + "\n", {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": cacheControl,
      "x-content-type-options": "nosniff",
    },
  });
}

function validateManifest(manifest, expectedStable) {
  if (!manifest || typeof manifest !== "object" || Array.isArray(manifest)) {
    return "manifest is not an object";
  }

  if (
    typeof manifest.version !== "string" ||
    !VERSION_RE.test(manifest.version)
  ) {
    return "invalid version";
  }

  if (
    manifest.channel !== "stable" &&
    manifest.channel !== "prerelease"
  ) {
    return "invalid channel";
  }

  if (expectedStable && manifest.channel !== "stable") {
    return "stable endpoint received a non-stable manifest";
  }

  if (manifest.platform !== "windows-x64") {
    return "unexpected platform";
  }

  if (typeof manifest.mandatory !== "boolean") {
    return "invalid mandatory flag";
  }

  if (
    typeof manifest.sha256 !== "string" ||
    !/^[0-9a-f]{64}$/i.test(manifest.sha256)
  ) {
    return "invalid sha256";
  }

  if (
    !Number.isInteger(manifest.size) ||
    manifest.size <= 0 ||
    manifest.size > MAX_UPDATE_BYTES
  ) {
    return "invalid size";
  }

  if (
    typeof manifest.download_url !== "string" ||
    !manifest.download_url.startsWith(DOWNLOAD_PREFIX)
  ) {
    return "unexpected download URL";
  }

  if (
    typeof manifest.release_page !== "string" ||
    !manifest.release_page.startsWith(RELEASE_PREFIX)
  ) {
    return "unexpected release page";
  }

  if (
    typeof manifest.notes !== "string" ||
    manifest.notes.length > 2000
  ) {
    return "invalid notes";
  }

  return null;
}

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed\n", {
        status: 405,
        headers: {
          allow: "GET, HEAD",
          "cache-control": "no-store",
          "content-type": "text/plain; charset=utf-8",
        },
      });
    }

    if (url.pathname === "/health") {
      const response = jsonResponse({
        service: "quantum-guard-update-edge",
        status: "ok",
        source: "typchris/Quantum-Guard",
      });
      return request.method === "HEAD"
        ? new Response(null, { status: response.status, headers: response.headers })
        : response;
    }

    const origin = MANIFESTS.get(url.pathname);
    if (!origin) {
      return jsonResponse({ error: "not_found" }, 404);
    }

    let upstream;
    try {
      upstream = await fetch(origin, {
        headers: {
          accept: "application/json",
          "user-agent": "QuantumGuard-Update-Edge/1.0",
        },
      });
    } catch (error) {
      console.error("Manifest origin fetch failed", error);
      return jsonResponse({ error: "origin_unreachable" }, 502);
    }

    if (!upstream.ok) {
      const status =
        url.pathname === "/updates/latest-stable.json" &&
        upstream.status === 404
          ? 404
          : 502;
      return jsonResponse(
        {
          error: status === 404 ? "stable_release_not_available" : "origin_error",
          origin_status: upstream.status,
        },
        status,
      );
    }

    let manifest;
    try {
      manifest = await upstream.json();
    } catch (error) {
      console.error("Manifest JSON parse failed", error);
      return jsonResponse({ error: "invalid_origin_json" }, 502);
    }

    const validationError = validateManifest(
      manifest,
      url.pathname === "/updates/latest-stable.json",
    );
    if (validationError) {
      console.error("Manifest validation failed", validationError);
      return jsonResponse(
        { error: "invalid_origin_manifest", detail: validationError },
        502,
      );
    }

    const response = jsonResponse(
      manifest,
      200,
      "public, max-age=60, s-maxage=60",
    );

    return request.method === "HEAD"
      ? new Response(null, { status: response.status, headers: response.headers })
      : response;
  },
};
