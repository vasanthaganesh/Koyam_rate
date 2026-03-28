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

    // 1. Get the updated price from the Webhook payload
    const payload = await req.json()
    const { record: updatedPrice } = payload
    
    if (!updatedPrice || !updatedPrice.item_eng) {
       console.log("No valid price record in payload")
       return new Response(JSON.stringify({ success: false, message: 'No price record' }), {
         headers: { ...corsHeaders, 'Content-Type': 'application/json' },
         status: 200,
       })
    }

    console.log(`🔍 Checking alerts for: ${updatedPrice.item_eng}`)

    // 2. Get today's IST date string
    const now = new Date()
    const istOffset = 5.5 * 60 * 60 * 1000 // UTC+5:30
    const istDate = new Date(now.getTime() + istOffset)
    const today = istDate.toISOString().split('T')[0]

    // 3. Process all alerts for this SPECIFIC item
    const notifications: any[] = []
    let from = 0
    
    while (true) {
      const { data: alerts, error: alertsError } = await supabaseClient
        .from('price_alerts')
        .select('*')
        .eq('item_name_eng', updatedPrice.item_eng)
        .eq('notify_active', true)
        .range(from, from + PAGE_SIZE - 1)

      if (alertsError) throw alertsError
      if (!alerts || alerts.length === 0) break

      for (const alert of alerts) {
        let trigger = false
        let condition = ''

        if (alert.min_price && updatedPrice.min_price < alert.min_price) {
          trigger = true
          condition = `dropped to ₹${updatedPrice.min_price} (Target: ₹${alert.min_price})`
        } else if (alert.max_price && updatedPrice.max_price > alert.max_price) {
          trigger = true
          condition = `rose to ₹${updatedPrice.max_price} (Target: ₹${alert.max_price})`
        }

        if (trigger) {
          // Deduplicate: Check if we sent an alert for this user/item TODAY
          const { data: existing, error: dupError } = await supabaseClient
            .from('notifications_queue')
            .select('id')
            .eq('user_id', alert.user_id)
            .eq('item_id', alert.item_id)
            .gte('created_at', today)
            .limit(1)

          if (dupError) throw dupError
          if (existing && existing.length > 0) {
            console.log(`⏩ Skipping duplicate for ${alert.user_id}/${updatedPrice.item_eng} today`)
            continue
          }

          notifications.push({
            user_id: alert.user_id,
            title: '🔥 Price Alert!',
            body: `${updatedPrice.item_eng} price ${condition}!`,
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
      console.log(`✅ Sent ${notifications.length} notifications`)
    }

    return new Response(JSON.stringify({ success: true, notifications_sent: notifications.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error(`❌ Edge Function Error: ${error.message}`)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})

