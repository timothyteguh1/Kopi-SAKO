import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
// KUNCI PERBAIKAN: Gunakan Nodemailer dari npm!
import nodemailer from "npm:nodemailer"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, phone } = await req.json()

    if (!email || !phone) {
      return new Response(JSON.stringify({ error: 'Email dan No. HP wajib diisi' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 })
    }

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString()
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString()

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    await supabaseClient.from('otp_requests').delete().eq('email', email)
    const { error: dbError } = await supabaseClient.from('otp_requests').insert({ email, phone_number: phone, otp_code: otpCode, expires_at: expiresAt })
    if (dbError) throw dbError

    // ==========================================
    // PROSES MENGIRIM EMAIL MENGGUNAKAN NODEMAILER (GMAIL)
    // ==========================================
    const gmailEmail = Deno.env.get('GMAIL_EMAIL') ?? ''
    const gmailPassword = Deno.env.get('GMAIL_APP_PASSWORD') ?? ''

    // Setup mesin pengirim
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailEmail,
        pass: gmailPassword,
      },
    });

    // Setup isi email
    const mailOptions = {
      from: `"Kopi SAKO" <${gmailEmail}>`,
      to: email, // Kirim ke email tujuan
      subject: 'Kode OTP Pendaftaran Akun SAKO',
      text: `Halo,\n\nKode OTP pendaftaran Anda adalah: ${otpCode}\n\nKode ini berlaku selama 5 menit. Jangan bagikan kepada siapapun.\n\nSalam,\nSistem Kopi SAKO`,
    };

    // Eksekusi pengiriman
    await transporter.sendMail(mailOptions);

    return new Response(JSON.stringify({ message: 'OTP berhasil dikirim!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 })
  }
})