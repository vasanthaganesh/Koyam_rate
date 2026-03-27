import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? 'https://koyamrate.app',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const PAGE_SIZE = 500;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Get today's prices (in IST)
    const now = new Date()
    const istOffset = 5.5 * 60 * 60 * 1000 // UTC+5:30
    const istDate = new Date(now.getTime() + istOffset)
    const today = istDate.toISOString().split('T')[0]
    const { data: prices, error: pricesError } = await supabaseClient
      .from('prices')
      .select('*')
      .eq('date', today)

    if (pricesError) throw pricesError
    if (!prices || prices.length === 0) {
      return new Response(JSON.stringify({ success: true, notifications_sent: 0, message: 'No prices for today yet.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // 2. Get existing unread notifications for deduplication
    const { data: existingNotifications, error: existingError } = await supabaseClient
      .from('notifications_queue')
      .select('user_id, item_id')
      .eq('is_read', false)

    if (existingError) throw existingError

    // 3. Process alerts in paginated batches
    const notifications: any[] = []
    let from = 0

    while (true) {
      const { data: alerts, error: alertsError } = await supabaseClient
        .from('price_alerts')
        .select('*')
        .eq('notify_active', true)
        .range(from, from + PAGE_SIZE - 1)

      if (alertsError) throw alertsError
      if (!alerts || alerts.length === 0) break

      for (const alert of alerts) {
        const price = prices.find((p: any) => p.item_eng === alert.item_name_eng)
        if (!price) continue

        let trigger = false
        let condition = ''

        if (alert.min_price && price.min_price < alert.min_price) {
          trigger = true
          condition = `dropped to ₹${price.min_price} (Target: ₹${alert.min_price})`
        } else if (alert.max_price && price.max_price > alert.max_price) {
          trigger = true
          condition = `rose to ₹${price.max_price} (Target: ₹${alert.max_price})`
        }

        if (trigger) {
          const isDuplicate = existingNotifications?.some(
            (n: any) => n.user_id === alert.user_id && n.item_id === alert.item_id
          )
          if (isDuplicate) continue

          notifications.push({
            user_id: alert.user_id,
            title: '🔥 Price Alert!',
            body: `${alert.item_name_eng} price ${condition}!`,
            item_id: alert.item_id,
            type: 'price_alert'
          })
        }
      }

      if (alerts.length < PAGE_SIZE) break
      from += PAGE_SIZE
    }

    // 4. Batch insert notifications
    if (notifications.length > 0) {
      const { error: notifyError } = await supabaseClient
        .from('notifications_queue')
        .insert(notifications)
      
      if (notifyError) throw notifyError
    }

    return new Response(JSON.stringify({ success: true, notifications_sent: notifications.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})

