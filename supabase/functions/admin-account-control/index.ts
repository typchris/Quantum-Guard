import "jsr:@supabase/functions-js@2.5.0/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });

const statusForRpcError = (message: string) => {
  const m = message.toLowerCase();
  if (
    m.includes("authentication required") ||
    m.includes("active account required") ||
    m.includes("not authorized") ||
    m.includes("organization")
  ) return 403;
  if (
    m.includes("target user") ||
    m.includes("status must") ||
    m.includes("cannot suspend or block themselves")
  ) return 400;
  return 500;
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "POST required" });

  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return json(401, { error: "missing bearer token" });

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: callerData, error: callerError } = await userClient.auth.getUser(token);
  if (callerError || !callerData.user) return json(401, { error: "invalid session" });

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "invalid JSON" });
  }

  const targetUserId = String(body?.target_user_id ?? "");
  const requested = String(body?.status ?? "").trim().toLowerCase();
  const reason = String(body?.reason ?? "").slice(0, 500);

  const { data: change, error: changeError } = await userClient.rpc(
    "apply_account_status_change",
    {
      p_target_user: targetUserId || null,
      p_status: requested,
      p_reason: reason || null,
    },
  );

  if (changeError) {
    return json(statusForRpcError(changeError.message), { error: changeError.message });
  }

  const result = (change ?? {}) as {
    ok?: boolean;
    operation_id?: string;
    status?: string;
    previous_status?: string;
    organizations_affected?: number;
    devices_notified?: number;
    audit_ids?: number[];
  };

  let authWarning: string | null = null;
  try {
    const banDuration = requested === "blocked" ? "876000h" : "none";
    const { error } = await admin.auth.admin.updateUserById(targetUserId, {
      ban_duration: banDuration,
    });
    if (error) authWarning = error.message;
  } catch (e) {
    authWarning = e instanceof Error ? e.message : String(e);
  }

  const auditIds = Array.isArray(result.audit_ids)
    ? result.audit_ids.filter((id) => Number.isInteger(id))
    : [];

  if (auditIds.length) {
    const { error: finalizeError } = await admin.rpc(
      "finalize_account_status_auth_sync",
      {
        p_audit_ids: auditIds,
        p_sync_status: authWarning ? "warning" : "ok",
        p_sync_error: authWarning,
      },
    );
    if (finalizeError) {
      authWarning = authWarning
        ? `${authWarning}; audit finalize failed: ${finalizeError.message}`
        : `audit finalize failed: ${finalizeError.message}`;
    }
  }

  return json(200, {
    ...result,
    auth_warning: authWarning,
  });
});
