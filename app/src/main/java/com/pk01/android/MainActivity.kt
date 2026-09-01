package com.pk01.android

import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView
import kotlin.concurrent.thread

class MainActivity : AppCompatActivity() {
    private val menu = listOf("Dashboard", "Proyek", "Pembelian Bahan", "PO Supplier", "Supplier", "Deposit", "Komisi", "Pembayaran", "Cash Perusahaan", "Laporan", "AI Assistant", "Pengaturan")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildHome())
    }

    private fun buildHome(): ScrollView {
        val scroll = ScrollView(this)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(28, 34, 28, 34) }
        root.addView(TextView(this).apply { text = "PK01 Office"; textSize = 30f; setTextColor(Color.rgb(25,30,38)) })
        root.addView(TextView(this).apply { text = "Manajemen proyek • Cash • Operasional • AI"; textSize = 14f; setTextColor(Color.DKGRAY); setPadding(0,4,0,22) })

        val card = MaterialCardView(this).apply { radius = 28f; cardElevation = 2f }
        val box = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(24,22,24,22) }
        val value = TextView(this).apply { text = if (ApiConfig.baseUrl.isBlank()) "API belum dikonfigurasi" else "Menghubungkan ke PK01…"; textSize = 20f }
        box.addView(TextView(this).apply { text = "CASH DI TANGAN"; textSize = 12f; setTextColor(Color.GRAY) })
        box.addView(value)
        card.addView(box)
        root.addView(card, LinearLayout.LayoutParams(-1,-2).apply { bottomMargin = 22 })

        val grid = GridLayout(this).apply { columnCount = 2 }
        menu.forEach { label ->
            val item = MaterialCardView(this).apply { radius = 22f; cardElevation = 1f; isClickable = true; setOnClickListener { Toast.makeText(this@MainActivity, "$label — modul PK01", Toast.LENGTH_SHORT).show() } }
            item.addView(TextView(this@MainActivity).apply { text = label; textSize = 15f; gravity = Gravity.CENTER_VERTICAL; setPadding(22,20,16,20) })
            grid.addView(item, GridLayout.LayoutParams().apply { width=0; height=150; columnSpec=GridLayout.spec(GridLayout.UNDEFINED,1f); setMargins(6,6,6,6) })
        }
        root.addView(grid)
        scroll.addView(root)

        if (ApiConfig.baseUrl.isNotBlank()) thread {
            try {
                val data = ApiClient(ApiConfig.baseUrl, ApiConfig.username, ApiConfig.applicationPassword).get(Pk01ApiContract.CASH).optJSONObject("data")
                val cash = data?.optDouble("cash", 0.0) ?: 0.0
                runOnUiThread { value.text = "Rp " + "%,.0f".format(cash).replace(',', '.') }
            } catch (_: Exception) { runOnUiThread { value.text = "API belum terhubung" } }
        }
        return scroll
    }
}
