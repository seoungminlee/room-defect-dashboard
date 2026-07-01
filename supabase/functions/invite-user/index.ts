import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, displayName, role } = await req.json();

    if (!email || !displayName || !role) {
      return new Response(
        JSON.stringify({ error: "email, displayName, role 모두 필요합니다." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (!["admin", "staff", "viewer"].includes(role)) {
      return new Response(
        JSON.stringify({ error: "role은 admin 또는 staff여야 합니다." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) {
      return new Response(
        JSON.stringify({ error: "인증 토큰이 없습니다." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

    // 1. 토큰으로 사용자 정보 조회 (REST API 직접 호출)
    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        "Authorization": `Bearer ${token}`,
        "apikey": SERVICE_ROLE_KEY,
      },
    });
    if (!userRes.ok) {
      return new Response(
        JSON.stringify({ error: "인증 실패: 토큰이 유효하지 않습니다." }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const caller = await userRes.json();
    if (caller.user_metadata?.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "관리자만 초대할 수 있습니다." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. 초대 발송 (Admin REST API 직접 호출)
    const inviteRes = await fetch(`${SUPABASE_URL}/auth/v1/invite`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
        "apikey": SERVICE_ROLE_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email,
        data: { display_name: displayName, role },
        redirect_to: Deno.env.get("SITE_URL") ?? undefined,
      }),
    });

    const inviteJson = await inviteRes.json();
    if (!inviteRes.ok) {
      return new Response(
        JSON.stringify({ error: inviteJson.msg || inviteJson.message || "초대 실패" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, userId: inviteJson.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return new Response(
      JSON.stringify({ error: "서버 오류: " + msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
