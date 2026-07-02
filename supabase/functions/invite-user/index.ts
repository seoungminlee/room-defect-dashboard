import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// v2.2: CORS를 사이트 도메인으로 제한 (SITE_URL 미설정 시에만 전체 허용)
const ALLOWED_ORIGIN = (() => {
  try { return new URL(Deno.env.get("SITE_URL") ?? "").origin; } catch { return "*"; }
})();
const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, displayName, role } = await req.json();

    if (!email || !displayName || !role) {
      return json({ error: "email, displayName, role 모두 필요합니다." }, 400);
    }
    if (!["admin", "staff", "viewer"].includes(role)) {
      return json({ error: "role은 admin, staff, viewer 중 하나여야 합니다." }, 400);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) {
      return json({ error: "인증 토큰이 없습니다." }, 401);
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

    // 1. 호출자 확인 — app_metadata.role 기준 (사용자가 스스로 수정 불가한 영역)
    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        "Authorization": `Bearer ${token}`,
        "apikey": SERVICE_ROLE_KEY,
      },
    });
    if (!userRes.ok) {
      return json({ error: "인증 실패: 토큰이 유효하지 않습니다." }, 401);
    }
    const caller = await userRes.json();
    if (caller.app_metadata?.role !== "admin") {
      return json({ error: "관리자만 초대할 수 있습니다." }, 403);
    }

    // 2. 초대 발송 (display_name만 user_metadata에, role은 넣지 않음)
    const inviteRes = await fetch(`${SUPABASE_URL}/auth/v1/invite`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
        "apikey": SERVICE_ROLE_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email,
        // must_change_pw: 비밀번호를 설정할 때까지 로그인마다 설정 창 강제 (v2.4)
        data: { display_name: displayName, must_change_pw: true },
        redirect_to: Deno.env.get("SITE_URL") ?? undefined,
      }),
    });

    // 응답이 JSON이 아닐 수 있음 (게이트웨이 타임아웃 등) — 안전 파싱
    const inviteText = await inviteRes.text();
    let inviteJson: Record<string, unknown> = {};
    try { inviteJson = JSON.parse(inviteText); } catch { /* plain text */ }

    if (!inviteRes.ok) {
      const detail = (inviteJson.msg || inviteJson.message || inviteText || "").toString().slice(0, 200);
      const hint = /timeout|timed out/i.test(detail)
        ? " — SMTP 연결 시간 초과입니다. Supabase SMTP 설정(호스트/포트/앱 비밀번호)을 확인하세요."
        : "";
      return json({ error: `초대 실패 (${inviteRes.status}): ${detail}${hint}` }, 400);
    }

    // 3. role을 app_metadata에 설정 (service_role 전용 Admin API)
    const metaRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${inviteJson.id}`, {
      method: "PUT",
      headers: {
        "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
        "apikey": SERVICE_ROLE_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ app_metadata: { role } }),
    });
    if (!metaRes.ok) {
      const metaText = await metaRes.text();
      let metaErr: Record<string, unknown> = {};
      try { metaErr = JSON.parse(metaText); } catch { /* plain text */ }
      return json({
        error: "초대는 발송됐으나 권한 설정 실패: " + (metaErr.msg || metaErr.message || metaText.slice(0, 200) || "알 수 없는 오류"),
        userId: inviteJson.id,
      }, 500);
    }

    return json({ success: true, userId: inviteJson.id }, 200);

  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: "서버 오류: " + msg }, 500);
  }
});
