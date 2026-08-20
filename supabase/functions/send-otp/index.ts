import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
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
    // TAMBAHAN: Tangkap parameter 'type'
    const { email, phone, type } = await req.json()

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

    const gmailEmail = Deno.env.get('GMAIL_EMAIL') ?? ''
    const gmailPassword = Deno.env.get('GMAIL_APP_PASSWORD') ?? ''

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailEmail,
        pass: gmailPassword,
      },
    });

    // ==================================================
    // LOGIKA PENENTUAN FORMAT EMAIL BERDASARKAN TIPE
    // ==================================================
    let emailSubject = '';
    let emailHtml = '';

    if (type === 'forgot_password') {
      emailSubject = 'Pemulihan Kata Sandi Kopi SAKO';
      emailHtml = `
        <div style="font-family: sans-serif; padding: 20px;">
          <h2>Lupa Kata Sandi?</h2>
          <p>Halo,</p>
          <p>Seseorang telah meminta pemulihan kata sandi untuk akun Pelanggan SAKO Anda.</p>
          <p>Kode OTP Anda adalah: <strong style="font-size: 24px; color: #E86A33;">${otpCode}</strong></p>
          <p>Masukkan kode 6-digit di atas ke dalam aplikasi. Kode ini hanya berlaku selama 5 menit.</p>
          <p>Jika Anda tidak memintanya, abaikan email ini.</p>
        </div>
      `;
    } else {
      // Format Default (Untuk Register)
      emailSubject = 'Kode OTP Pendaftaran Akun SAKO';
      emailHtml = `
        <div style="font-family: sans-serif; padding: 20px;">
          <h2>Selamat Datang di Kopi SAKO!</h2>
          <p>Halo,</p>
          <p>Kode OTP pendaftaran Anda adalah: <strong style="font-size: 24px; color: #E86A33;">${otpCode}</strong></p>
          <p>Kode ini berlaku selama 5 menit. Jangan bagikan kepada siapapun.</p>
        </div>
      `;
    }

    const mailOptions = {
      from: `"Kopi SAKO" <${gmailEmail}>`,
      to: email,
      subject: emailSubject,
      html: emailHtml, // Menggunakan HTML agar tampilannya lebih cantik
    };

    await transporter.sendMail(mailOptions);

    return new Response(JSON.stringify({ message: 'OTP berhasil dikirim!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 })
  }
})