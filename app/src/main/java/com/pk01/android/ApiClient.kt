package com.pk01.android

import android.util.Base64
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class ApiClient(private val baseUrl: String, private val username: String, private val applicationPassword: String) {
    fun get(path: String): JSONObject = request("GET", path, null)
    fun post(path: String, body: JSONObject): JSONObject = request("POST", path, body.toString())

    private fun request(method: String, path: String, body: String?): JSONObject {
        require(baseUrl.isNotBlank()) { "URL API belum diatur." }
        val conn = (URL(baseUrl.trimEnd('/') + "/" + path.trimStart('/')).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15000
            readTimeout = 20000
            setRequestProperty("Accept", "application/json")
            if (username.isNotBlank() && applicationPassword.isNotBlank()) {
                val token = "$username:$applicationPassword"
                setRequestProperty("Authorization", "Basic " + Base64.encodeToString(token.toByteArray(), Base64.NO_WRAP))
            }
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                outputStream.use { it.write(body.toByteArray()) }
            }
        }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() } ?: ""
        conn.disconnect()
        if (code !in 200..299) throw IllegalStateException("API $code: $text")
        return JSONObject(text)
    }
}
