import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
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
    const { userId } = await req.json();
    if (!userId) {
      return json({ error: "userId가 필요합니다." }, 400);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) {
      return json({ error: "인증 토큰이 없습니다." }, 401);
    }

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

    // 호출자 확인 — app_metadata.role 기준 (사용자가 스스로 수정 불가한 영역)
    const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        "Authorization": `Bearer ${token}`,
        "apikey": SERVICE_ROLE_KEY,
      },
    });
    if (!userRes.ok) {
      return json({ error: "인증 실패" }, 401);
    }
    const caller = await userRes.json();
    if (caller.app_metadata?.role !== "admin") {
      return json({ error: "관리자만 삭제할 수 있습니다." }, 403);
    }

    // 자기 자신 삭제 방지
    if (caller.id === userId) {
      return json({ error: "자기 자신은 삭제할 수 없습니다." }, 400);
    }

    // 삭제
    const delRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`, {
      method: "DELETE",
      headers: {
        "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
        "apikey": SERVICE_ROLE_KEY,
      },
    });

    if (!delRes.ok) {
      const err = await delRes.json();
      return json({ error: err.msg || err.message || "삭제 실패" }, 400);
    }

    return json({ success: true }, 200);

  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ error: "서버 오류: " + msg }, 500);
  }
});
