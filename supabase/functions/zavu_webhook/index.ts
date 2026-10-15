import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // ============ DEBUG ENV VARS ============
  const SUPABASE_URL = 'https://pvdidrqekdsnvrjtylrq.supabase.co'
  const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2ZGlkcnFla2RzbnZyanR5bHJxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MjAyMDc3OSwiZXhwIjoyMTA3NTk2Nzc5fQ.5XcXzCj9TZsck8D7NYpaOmDsMojyqDOIuPvZY2fg32M'
  const ZAVU_API_KEY = 'zv_live_24df8f6f3ae3fbb2085eed14f8d2c3a0bdf8c24274352527'
  const ZAVU_SENDER_ID = 'kd7c1645a3zx9vzq228x02exp98gabgw'

  console.log('=== DEBUG ENV VARS ===')
  console.log('SUPABASE_URL:', SUPABASE_URL)
  console.log('SERVICE_KEY exists:', !!SUPABASE_SERVICE_KEY)
  console.log('ZAVU_API_KEY exists:', !!ZAVU_API_KEY)
  console.log('ZAVU_SENDER_ID:', ZAVU_SENDER_ID)
  console.log('======================')
  // ========================================

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
      throw new Error(`Missing env vars. URL: ${!!SUPABASE_URL}, KEY: ${!!SUPABASE_SERVICE_KEY}`)
    }

    const body = await req.json()
    console.log('📩 Webhook recibido:', JSON.stringify(body))

    const from = body.from || body.sender || body.phone || ''
    const text = (body.text || body.message || body.body || '').toLowerCase().trim()

    console.log(`De: ${from} | Mensaje: "${text}"`)

    const phoneNormalized = from.startsWith('+') ? from : `+${from}`

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    const acceptKeywords = ['SI','Si','SÍ','sí', 'si', 'sí.', 'si.', 'yes', 'acepto', 'claro', 'ok']
    const rejectKeywords = ['No','NO','no', 'no.', 'rechazo', 'nop']

    let respuesta = ''
    let nuevoStatus = ''

    if (acceptKeywords.includes(text)) {
      nuevoStatus = 'accepted'
      respuesta = '✅ ¡Gracias! Ya eres parte del círculo de confianza de MOSCA.'

      const { data, error } = await supabase
        .from('contacts')
        .update({ status: 'accepted' })
        .eq('contact_phone', phoneNormalized)
        .eq('status', 'pending')
        .select()

      console.log('✅ Contacto actualizado:', data, '| Error:', error)
    } else if (rejectKeywords.includes(text)) {
      nuevoStatus = 'rejected'
      respuesta = 'Entendido. Hemos notificado al usuario.'

      await supabase
        .from('contacts')
        .update({ status: 'rejected' })
        .eq('contact_phone', phoneNormalized)
        .eq('status', 'pending')
    } else {
      respuesta = 'Hola 👋 Responde "SÍ" para aceptar, o "NO" para rechazar.'
    }

    if (respuesta && nuevoStatus !== '' && ZAVU_API_KEY && ZAVU_SENDER_ID) {
      await fetch('https://api.zavu.dev/v1/messages', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${ZAVU_API_KEY}`,
          'Zavu-Sender': ZAVU_SENDER_ID,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: phoneNormalized,
          channel: 'whatsapp',
          text: respuesta,
        }),
      })
    }

    return new Response(
      JSON.stringify({ ok: true, status: nuevoStatus || 'unknown' }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Error:', error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})