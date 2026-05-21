// Optional Edge Function for Phase 1 email notifications.
// Deploy: supabase functions deploy send-leave-email
// Secrets: RESEND_API_KEY, RESEND_FROM (e.g. leave@yourdomain.com)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { leave_id, event } = await req.json();
    const resendKey = Deno.env.get("RESEND_API_KEY");
    const from = Deno.env.get("RESEND_FROM") ?? "onboarding@resend.dev";

    if (!resendKey) {
      return new Response(
        JSON.stringify({ ok: false, message: "RESEND_API_KEY not configured" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: leave } = await supabase
      .from("leave_requests")
      .select("*")
      .eq("id", leave_id)
      .single();

    if (!leave) {
      return new Response(JSON.stringify({ ok: false, message: "Leave not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: emp } = await supabase
      .from("users")
      .select("email, name, manager_user_id")
      .eq("employee_id", leave.employeeID)
      .single();

    const recipients: string[] = [];
    if (emp?.email) recipients.push(emp.email);

    if (event === "submitted" && emp?.manager_user_id) {
      const { data: mgr } = await supabase
        .from("users")
        .select("email")
        .eq("id", emp.manager_user_id)
        .single();
      if (mgr?.email) recipients.push(mgr.email);
    }

    const subject = `Leave ${event}: ${emp?.name ?? "Employee"}`;
    const body = `${emp?.name ?? "Employee"} — ${leave.leave_type} from ${leave.date_start} to ${leave.date_end} (${event}).`;

    for (const to of [...new Set(recipients)]) {
      await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ from, to, subject, text: body }),
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, message: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
