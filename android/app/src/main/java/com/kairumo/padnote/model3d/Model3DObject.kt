package com.kairumo.padnote.model3d

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import uniffi.padnote_core.FfiMaterial
import uniffi.padnote_core.model3dMaterialLook
import uniffi.padnote_core.model3dMaterials

/**
 * 畫布上的一個 3D 模型。
 *
 * # 鍵名不能改
 *
 * 這份 JSON 存在筆記的中繼資料 `model3DAttachments` 底下，**與 Apple 端的
 * `Note3DAttachment` 是同一份資料**。欄位名稱是 Swift `Codable` 用屬性名
 * 自動產生的，所以這裡的字串必須逐字相同 —— 拼錯不會報錯，只會讓在 iPad 上
 * 放的模型在 Android 上變不見（反之亦然）。
 *
 * `materialType` 存的是 Apple `MaterialType` 的 rawValue（中文字串）。
 * 那是既有的落盤格式，不是介面文字 —— 改成英文會讓舊筆記讀不到材質。
 * 介面上顯示的名稱走 `model3dMaterialLook().nameKey` 查語系表。
 */
data class Model3DObject(
    val id: String = UUID.randomUUID().toString(),
    var pageIndex: Int = 0,
    var title: String = "",
    var modelTypeRaw: String = "sphere",
    var materialRaw: String = model3dMaterialLook(FfiMaterial.GOLD).raw,
    var rotationX: Float = 0.35f,
    var rotationY: Float = 0.6f,
    var rotationZ: Float = 0f,
    var scale: Float = 1f,
    var x: Float = 60f,
    var y: Float = 120f,
    var width: Float = 240f,
    var height: Float = 240f,
    /** 畫布上的旋轉角度（度）。與其他物件共用同一個概念。 */
    var rotationDegrees: Double = 0.0,
    /**
     * 匯入的模型檔名（在筆記本的附件目錄下）。`null` 代表用內建幾何體。
     *
     * **這一側畫不出來。** Android 沒有內建的 USDZ／GLB 算繪器，
     * 而為了一個模型預覽把 Filament 那種等級的相依拉進來，代價與收益
     * 不成比例（見 `Model3DLayer` 的說明）。
     *
     * 但檔案**存得下也同步得動** —— 使用者在 iPad 上插的模型，
     * 在這裡看得到它在那裡、搬得動、改得了邊框，只是畫面上顯示的是檔名
     * 而不是模型。這比「同步過來之後那個物件整個不見」好得多。
     */
    var importedFileName: String? = null,
    /** 使用者原本的檔名，只拿來顯示。 */
    var importedDisplayName: String? = null
) {
    /** 材質列舉。認不得的字串退回黃金 —— 與 Apple 端「壞資料仍要開得起來」一致。 */
    val material: FfiMaterial
        get() = model3dMaterials().firstOrNull { model3dMaterialLook(it).raw == materialRaw }
            ?: FfiMaterial.GOLD
}

/** `model3DAttachments` 的編解碼。 */
object Model3DCodec {

    fun decodeAll(array: JSONArray?): MutableList<Model3DObject> {
        val out = mutableListOf<Model3DObject>()
        if (array == null) return out
        for (i in 0 until array.length()) {
            val o = array.optJSONObject(i) ?: continue
            // id 是必要的：沒有 id 的物件排不進圖層、也存不回去。
            val id = o.optString("id").takeIf { it.isNotEmpty() } ?: continue
            out += Model3DObject(
                id = id,
                pageIndex = o.optInt("pageIndex", 0),
                title = o.optString("title", ""),
                modelTypeRaw = o.optString("modelTypeRaw", "sphere"),
                materialRaw = o.optString("materialType", model3dMaterialLook(FfiMaterial.GOLD).raw),
                rotationX = o.optDouble("rotationX", 0.35).toFloat(),
                rotationY = o.optDouble("rotationY", 0.6).toFloat(),
                rotationZ = o.optDouble("rotationZ", 0.0).toFloat(),
                scale = o.optDouble("scale", 1.0).toFloat(),
                x = o.optDouble("x", 60.0).toFloat(),
                y = o.optDouble("y", 120.0).toFloat(),
                width = o.optDouble("width", 240.0).toFloat(),
                height = o.optDouble("height", 240.0).toFloat(),
                rotationDegrees = o.optDouble("rotationDegrees", 0.0)
            )
        }
        return out
    }

    fun encodeAll(items: List<Model3DObject>): JSONArray {
        val array = JSONArray()
        for (m in items) {
            array.put(
                JSONObject().apply {
                    put("id", m.id)
                    put("pageIndex", m.pageIndex)
                    put("title", m.title)
                    put("modelTypeRaw", m.modelTypeRaw)
                    put("materialType", m.materialRaw)
                    put("rotationX", m.rotationX.toDouble())
                    put("rotationY", m.rotationY.toDouble())
                    put("rotationZ", m.rotationZ.toDouble())
                    put("scale", m.scale.toDouble())
                    put("x", m.x.toDouble())
                    put("y", m.y.toDouble())
                    put("width", m.width.toDouble())
                    put("height", m.height.toDouble())
                    put("rotationDegrees", m.rotationDegrees)
                    // Apple 端這三個是 Optional，不寫就是 nil，套用它自己的預設 ——
                    // 硬寫一個值進去等於幫使用者決定了外框樣式。
                    put("hasBorder", false)
                    put("cornerRadius", 12.0)
                }
            )
        }
        return array
    }
}
