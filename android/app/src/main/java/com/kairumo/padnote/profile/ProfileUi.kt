package com.kairumo.padnote.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.fragment.app.FragmentActivity
import com.kairumo.padnote.L10n
import kotlinx.coroutines.launch

/**
 * 設定檔（使用者）的介面（Android）：切換、新增、管理、鎖定畫面。
 * 與 Apple 端的 `ProfileViews.swift` 對應 —— 同樣的畫面、同樣的識別碼（`testTag`）、同樣的規則。
 * 規則（上限、名稱、PIN 格式）在 [ProfileRegistry] 與 [ProfileLockService]，切換在 [ProfileSwitcher]，
 * 這裡只管畫出來、收使用者的操作。
 */

private fun parseColor(hex: String): Color =
    runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Color(0xFF007AFF))

@Composable
fun ProfileAvatar(name: String, colorHex: String, size: Int = 42) {
    Box(
        modifier = Modifier.size(size.dp).clip(CircleShape).background(parseColor(colorHex)),
        contentAlignment = Alignment.Center
    ) {
        Text(
            name.take(1).uppercase(),
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = (size * 0.45).sp
        )
    }
}

internal fun errorText(error: Throwable): String = when (error) {
    is ProfileException -> when (error.kind) {
        ProfileException.Kind.INVALID_NAME -> L10n.t("profile_error_name")
        ProfileException.Kind.DUPLICATE_NAME -> L10n.t("profile_error_duplicate")
        ProfileException.Kind.LIMIT_REACHED -> L10n.f("profile_limit_reached", ProfileRegistry.MAX_PROFILES)
        ProfileException.Kind.CANNOT_DELETE_DEFAULT -> L10n.t("profile_delete_default")
        ProfileException.Kind.CANNOT_DELETE_ACTIVE -> L10n.t("profile_delete_active")
        ProfileException.Kind.INVALID_PIN -> L10n.t("profile_pin_invalid")
        ProfileException.Kind.PIN_STORAGE_FAILED -> L10n.t("profile_error_pin_storage")
        ProfileException.Kind.WRONG_PIN -> L10n.f("profile_pin_wrong", 0)
        else -> L10n.t("profile_error_generic")
    }
    else -> L10n.t("profile_error_generic")
}

private fun pinFailureText(result: PinVerifyResult): String? = when (result) {
    PinVerifyResult.Ok, PinVerifyResult.NoPin -> null
    is PinVerifyResult.Wrong -> L10n.f("profile_pin_wrong", result.attemptsBeforeLock)
    is PinVerifyResult.LockedOut -> {
        val seconds = maxOf(1L, (result.untilMillis - System.currentTimeMillis() + 999) / 1000)
        val text = if (seconds >= 60) "${seconds / 60}:%02d".format(seconds % 60) else "$seconds s"
        L10n.f("profile_pin_locked", text)
    }
}

/** 只收數字的 PIN 輸入欄。 */
@Composable
private fun PinField(label: String, value: String, tag: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = { next -> onChange(next.filter { it in '0'..'9' }.take(ProfileLockService.MAX_DIGITS)) },
        label = { Text(label) },
        singleLine = true,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
        modifier = Modifier.fillMaxWidth().testTag(tag)
    )
}

private sealed interface Page {
    object List : Page
    object Create : Page
    data class Edit(val id: String) : Page
    data class Unlock(val id: String) : Page
    data class PinSetup(val id: String) : Page
}

/** 切換選單。 */
@OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)
@Composable
fun ProfilePickerDialog(activity: FragmentActivity, onDismiss: () -> Unit) {
    var page by remember { mutableStateOf<Page>(Page.List) }
    var registry by remember { mutableStateOf(ProfileManager.registry(activity)) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    fun refresh() { registry = ProfileManager.registry(activity) }

    fun startSwitch(id: String, unlocked: Boolean) {
        scope.launch {
            if (unlocked) ProfileGate.markJustUnlockedFor(activity, id)
            when (ProfileSwitcher().switchTo(activity, id)) {
                ProfileSwitcher.Result.Switched -> Unit  // 行程即將重啟
                ProfileSwitcher.Result.AlreadyActive -> onDismiss()
                else -> error = L10n.t("profile_error_generic")
            }
        }
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            shape = RoundedCornerShape(20.dp),
            tonalElevation = 6.dp,
            modifier = Modifier.widthIn(max = 520.dp).fillMaxWidth().padding(16.dp)
                .semantics { testTagsAsResourceId = true }  // Dialog 是獨立視窗：自己要開
                .testTag("profile.picker")
        ) {
            Column(Modifier.padding(20.dp)) {
                when (val current = page) {
                    Page.List -> ListPage(
                        registry, error,
                        onSelect = { record ->
                            error = null
                            when {
                                record.id == registry.activeId -> onDismiss()
                                record.lock.isEnabled -> page = Page.Unlock(record.id)
                                else -> startSwitch(record.id, unlocked = false)
                            }
                        },
                        onManage = { page = Page.Edit(it.id) },
                        onAdd = { page = Page.Create },
                        onDone = onDismiss
                    )
                    Page.Create -> CreatePage(
                        activity,
                        onCancel = { page = Page.List },
                        onCreated = { record ->
                            refresh()
                            startSwitch(record.id, unlocked = true)
                        }
                    )
                    is Page.Edit -> EditPage(
                        activity, current.id,
                        onBack = { refresh(); page = Page.List },
                        onSetPin = { page = Page.PinSetup(current.id) },
                        onChanged = { refresh() }
                    )
                    is Page.PinSetup -> PinSetupPage(
                        activity, current.id,
                        onBack = { refresh(); page = Page.Edit(current.id) }
                    )
                    is Page.Unlock -> UnlockPage(
                        activity, registry.profile(current.id) ?: return@Column,
                        onCancel = { page = Page.List },
                        onUnlocked = { startSwitch(current.id, unlocked = true) }
                    )
                }
            }
        }
    }
}

@Composable
private fun ListPage(
    registry: ProfileRegistry,
    error: String?,
    onSelect: (ProfileRecord) -> Unit,
    onManage: (ProfileRecord) -> Unit,
    onAdd: () -> Unit,
    onDone: () -> Unit
) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(L10n.t("profile_picker_title"), style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
        TextButton(onClick = onDone, modifier = Modifier.testTag("profile.picker.done")) { Text(L10n.t("done")) }
    }
    Spacer(Modifier.height(8.dp))
    LazyColumn(Modifier.fillMaxWidth()) {
        items(registry.profiles, key = { it.id }) { record ->
            val isActive = record.id == registry.activeId
            Row(
                Modifier.fillMaxWidth().padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(
                    Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).clickable { onSelect(record) }
                        .padding(8.dp).testTag("profile.row.${record.id}"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    ProfileAvatar(record.displayName, record.colorHex)
                    Column(Modifier.weight(1f)) {
                        Text(record.displayName, fontWeight = FontWeight.SemiBold)
                        val sub = when {
                            isActive -> L10n.t("profile_current")
                            record.googleEmail != null -> record.googleEmail
                            record.lock.isEnabled -> L10n.t("profile_lock_on_hint")
                            else -> ""
                        }
                        if (!sub.isNullOrEmpty()) {
                            Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    when {
                        isActive -> Text("✓", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                        record.lock.isEnabled -> Text("🔒")
                    }
                }
                TextButton(onClick = { onManage(record) }, modifier = Modifier.testTag("profile.manage.${record.id}")) {
                    Text("⋯", fontSize = 20.sp)
                }
            }
        }
    }
    Spacer(Modifier.height(8.dp))
    TextButton(
        onClick = onAdd,
        enabled = registry.canAdd,
        modifier = Modifier.testTag("profile.add")
    ) { Text("＋ " + L10n.t("profile_add")) }
    if (!registry.canAdd) {
        Text(
            L10n.f("profile_limit_reached", ProfileRegistry.MAX_PROFILES),
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
    error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 8.dp)) }
}

@Composable
private fun CreatePage(activity: FragmentActivity, onCancel: () -> Unit, onCreated: (ProfileRecord) -> Unit) {
    var name by remember { mutableStateOf("") }
    val used = ProfileManager.registry(activity).profiles.map { it.colorHex }
    var color by remember { mutableStateOf(ProfileRegistry.PALETTE.firstOrNull { it !in used } ?: ProfileRegistry.DEFAULT_COLOR) }
    var useLock by remember { mutableStateOf(false) }
    var pin by remember { mutableStateOf("") }
    var pin2 by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    Text(L10n.t("profile_create_title"), style = MaterialTheme.typography.titleLarge)
    Spacer(Modifier.height(12.dp))
    OutlinedTextField(
        value = name, onValueChange = { name = it }, singleLine = true,
        label = { Text(L10n.t("profile_name")) },
        placeholder = { Text(L10n.t("profile_name_placeholder")) },
        modifier = Modifier.fillMaxWidth().testTag("profile.create.name")
    )
    Spacer(Modifier.height(8.dp))
    ColorChoices(color) { color = it }
    Text(L10n.t("profile_create_footer"), style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(vertical = 8.dp))
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(L10n.t("profile_lock_set"), modifier = Modifier.weight(1f))
        Switch(checked = useLock, onCheckedChange = { useLock = it }, modifier = Modifier.testTag("profile.create.lock"))
    }
    if (useLock) {
        PinField(L10n.t("profile_pin_new"), pin, "profile.create.pin") { pin = it }
        PinField(L10n.t("profile_pin_confirm"), pin2, "profile.create.pin2") { pin2 = it }
        Text(L10n.t("profile_lock_note"), style = MaterialTheme.typography.bodySmall)
    }
    error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("profile.create.error")) }
    Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.End) {
        TextButton(onClick = onCancel) { Text(L10n.t("cancel")) }
        Button(
            modifier = Modifier.testTag("profile.create.confirm"),
            onClick = {
                error = null
                if (useLock) {
                    if (!ProfileLockService.isValidPin(pin)) { error = L10n.t("profile_pin_invalid"); return@Button }
                    if (pin != pin2) { error = L10n.t("profile_pin_mismatch"); return@Button }
                }
                try {
                    val record = ProfileManager.createProfile(activity, name, color)
                    if (useLock) {
                        try {
                            ProfileManager.setPin(activity, pin, record.id)
                        } catch (e: Exception) {
                            // 要鎖卻設不上：整個回滾（見 Apple 端）。
                            runCatching { ProfileManager.deleteProfile(activity, record.id) }
                            throw e
                        }
                    }
                    onCreated(record)
                } catch (e: Exception) {
                    error = errorText(e)
                }
            }
        ) { Text(L10n.t("profile_create_button")) }
    }
}

@Composable
private fun ColorChoices(selected: String, onSelect: (String) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.testTag("profile.colors")) {
        ProfileRegistry.PALETTE.forEach { hex ->
            Box(
                Modifier.size(30.dp).clip(CircleShape).background(parseColor(hex))
                    .clickable { onSelect(hex) }
                    .padding(if (hex == selected) 0.dp else 3.dp),
                contentAlignment = Alignment.Center
            ) {
                if (hex == selected) Text("✓", color = Color.White, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun EditPage(
    activity: FragmentActivity,
    id: String,
    onBack: () -> Unit,
    onSetPin: () -> Unit,
    onChanged: () -> Unit
) {
    var registry by remember { mutableStateOf(ProfileManager.registry(activity)) }
    val record = registry.profile(id) ?: run { onBack(); return }
    var name by remember { mutableStateOf(record.displayName) }
    var error by remember { mutableStateOf<String?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    var removePin by remember { mutableStateOf<String?>(null) }
    fun reload() { registry = ProfileManager.registry(activity); onChanged() }

    Text(record.displayName, style = MaterialTheme.typography.titleLarge)
    Spacer(Modifier.height(8.dp))
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedTextField(
            value = name, onValueChange = { name = it }, singleLine = true,
            label = { Text(L10n.t("profile_name")) },
            modifier = Modifier.weight(1f).testTag("profile.edit.name")
        )
        TextButton(
            enabled = name.trim() != record.displayName,
            modifier = Modifier.testTag("profile.edit.save"),
            onClick = {
                error = null
                try { ProfileManager.renameProfile(activity, id, name); reload() } catch (e: Exception) { error = errorText(e) }
            }
        ) { Text(L10n.t("profile_save")) }
    }
    Spacer(Modifier.height(8.dp))
    ColorChoices(record.colorHex) { hex ->
        try { ProfileManager.setProfileColor(activity, id, hex); reload() } catch (e: Exception) { error = errorText(e) }
    }
    Spacer(Modifier.height(12.dp))
    Row(Modifier.fillMaxWidth()) {
        Text(L10n.t("profile_google_account"), modifier = Modifier.weight(1f))
        Text(record.googleEmail ?: L10n.t("profile_google_none"), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    Spacer(Modifier.height(12.dp))
    Text(L10n.t("profile_lock_section"), style = MaterialTheme.typography.titleSmall)
    Text(
        when {
            record.lock.useBiometrics -> L10n.t("profile_lock_on_bio")
            record.lock.hasPin -> L10n.t("profile_lock_on_pin")
            else -> L10n.t("profile_lock_off")
        },
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
    TextButton(onClick = onSetPin, modifier = Modifier.testTag("profile.edit.setpin")) {
        Text(if (record.lock.hasPin) L10n.t("profile_lock_change") else L10n.t("profile_lock_set"))
    }
    if (record.lock.hasPin) {
        if (ProfileBiometrics.isAvailable(activity)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(L10n.t("profile_lock_biometrics"), modifier = Modifier.weight(1f))
                Switch(
                    checked = record.lock.useBiometrics,
                    modifier = Modifier.testTag("profile.edit.biometrics"),
                    onCheckedChange = { on ->
                        try { ProfileManager.setBiometrics(activity, id, on); reload() } catch (e: Exception) { error = errorText(e) }
                    }
                )
            }
        }
        TextButton(onClick = { removePin = "" }, modifier = Modifier.testTag("profile.edit.removelock")) {
            Text(L10n.t("profile_lock_remove"), color = MaterialTheme.colorScheme.error)
        }
    }
    Text(L10n.t("profile_lock_note"), style = MaterialTheme.typography.bodySmall)
    Spacer(Modifier.height(8.dp))
    val isActive = id == registry.activeId
    TextButton(
        onClick = { confirmDelete = true },
        enabled = !record.isDefault && !isActive,
        modifier = Modifier.testTag("profile.edit.delete")
    ) { Text(L10n.t("profile_delete"), color = MaterialTheme.colorScheme.error) }
    if (record.isDefault) {
        Text(L10n.t("profile_delete_default"), style = MaterialTheme.typography.bodySmall)
    } else if (isActive) {
        Text(L10n.t("profile_delete_active"), style = MaterialTheme.typography.bodySmall)
    }
    error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        TextButton(onClick = onBack, modifier = Modifier.testTag("profile.edit.done")) { Text(L10n.t("done")) }
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text(L10n.f("profile_delete_title", record.displayName)) },
            text = { Text(L10n.f("profile_delete_message", record.displayName)) },
            confirmButton = {
                TextButton(
                    modifier = Modifier.testTag("profile.edit.delete.confirm"),
                    onClick = {
                        confirmDelete = false
                        try { ProfileManager.deleteProfile(activity, id); onBack() } catch (e: Exception) { error = errorText(e) }
                    }
                ) { Text(L10n.t("profile_delete"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(L10n.t("cancel")) } }
        )
    }
    removePin?.let { typed ->
        AlertDialog(
            onDismissRequest = { removePin = null },
            title = { Text(L10n.t("profile_lock_remove")) },
            text = { PinField(L10n.t("profile_pin_current"), typed, "profile.edit.removelock.pin") { removePin = it } },
            confirmButton = {
                TextButton(onClick = {
                    try { ProfileManager.removeLock(activity, id, typed); removePin = null; reload() }
                    catch (e: Exception) { error = errorText(e); removePin = null }
                }) { Text(L10n.t("profile_lock_remove"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { removePin = null }) { Text(L10n.t("cancel")) } }
        )
    }
}

/** 設定或更換 PIN。已經有 PIN 時要先輸入目前的（否則走過來的人按一下就換掉你的鎖）。 */
@Composable
private fun PinSetupPage(activity: FragmentActivity, id: String, onBack: () -> Unit) {
    val hasPin = ProfileManager.registry(activity).profile(id)?.lock?.hasPin ?: false
    var current by remember { mutableStateOf("") }
    var pin by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    Text(if (hasPin) L10n.t("profile_lock_change") else L10n.t("profile_lock_set"), style = MaterialTheme.typography.titleLarge)
    Spacer(Modifier.height(8.dp))
    if (hasPin) PinField(L10n.t("profile_pin_current"), current, "profile.pin.current") { current = it }
    PinField(L10n.t("profile_pin_new"), pin, "profile.pin.new") { pin = it }
    PinField(L10n.t("profile_pin_confirm"), confirm, "profile.pin.confirm") { confirm = it }
    Text(L10n.t("profile_lock_note"), style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 8.dp))
    error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag("profile.pin.error")) }
    Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.End) {
        TextButton(onClick = onBack) { Text(L10n.t("cancel")) }
        Button(
            modifier = Modifier.testTag("profile.pin.save"),
            onClick = {
                error = null
                if (hasPin) {
                    val result = ProfileManager.verifyPin(activity, current, id)
                    if (result != PinVerifyResult.Ok) { error = pinFailureText(result); return@Button }
                }
                if (!ProfileLockService.isValidPin(pin)) { error = L10n.t("profile_pin_invalid"); return@Button }
                if (pin != confirm) { error = L10n.t("profile_pin_mismatch"); return@Button }
                try { ProfileManager.setPin(activity, pin, id); onBack() } catch (e: Exception) { error = errorText(e) }
            }
        ) { Text(L10n.t("profile_save")) }
    }
}

/** 解鎖（切換前）。 */
@Composable
private fun UnlockPage(activity: FragmentActivity, record: ProfileRecord, onCancel: () -> Unit, onUnlocked: () -> Unit) {
    var pin by remember { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    val biometricsOn = record.lock.useBiometrics && ProfileBiometrics.isAvailable(activity)

    fun tryBiometrics() {
        ProfileBiometrics.authenticate(activity, L10n.t("profile_unlock_biometric_reason"), L10n.t("cancel")) { ok ->
            if (ok) {
                ProfileManager.lockService(activity).noteBiometricSuccess(record.id)
                onUnlocked()
            }
        }
    }
    LaunchedEffect(record.id) { if (biometricsOn) tryBiometrics() }

    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        ProfileAvatar(record.displayName, record.colorHex, 72)
        Text(L10n.f("profile_unlock_title", record.displayName), style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(12.dp))
        PinField(L10n.t("profile_pin_enter"), pin, "profile.unlock.pin") { pin = it }
        message?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(8.dp).testTag("profile.unlock.message")) }
        Spacer(Modifier.height(8.dp))
        Button(
            enabled = pin.length >= ProfileLockService.MIN_DIGITS,
            modifier = Modifier.testTag("profile.unlock.button"),
            onClick = {
                val result = ProfileManager.verifyPin(activity, pin, record.id)
                if (result == PinVerifyResult.Ok) onUnlocked() else { message = pinFailureText(result); pin = "" }
            }
        ) { Text(L10n.t("profile_unlock_button")) }
        if (biometricsOn) {
            TextButton(onClick = { tryBiometrics() }, modifier = Modifier.testTag("profile.unlock.biometrics")) {
                Text(L10n.t("profile_use_biometrics"))
            }
        }
        TextButton(onClick = onCancel) { Text(L10n.t("cancel")) }
    }
}

/**
 * 鎖定畫面：使用中的設定檔上了鎖，啟動或離開一分鐘以上再回來時顯示。
 * **只是畫面閘門** —— 資料已經在記憶體裡（見 [ProfileLockService]）。
 */
@Composable
fun ProfileLockScreen(activity: FragmentActivity, onUnlocked: () -> Unit) {
    val registry = ProfileManager.registry(activity)
    val record = registry.active
    var pin by remember { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var showPicker by remember { mutableStateOf(false) }
    val biometricsOn = record.lock.useBiometrics && ProfileBiometrics.isAvailable(activity)

    fun tryBiometrics() {
        ProfileBiometrics.authenticate(activity, L10n.t("profile_unlock_biometric_reason"), L10n.t("cancel")) { ok ->
            if (ok) {
                ProfileManager.lockService(activity).noteBiometricSuccess(record.id)
                ProfileGate.unlock()
                onUnlocked()
            }
        }
    }
    LaunchedEffect(record.id) { if (biometricsOn) tryBiometrics() }

    Surface(Modifier.fillMaxSize().testTag("profile.lock")) {
        Column(
            Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            ProfileAvatar(record.displayName, record.colorHex, 88)
            Text(L10n.f("profile_unlock_title", record.displayName), style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(16.dp))
            Box(Modifier.widthIn(max = 300.dp)) { PinField(L10n.t("profile_pin_enter"), pin, "profile.lock.pin") { pin = it } }
            message?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(8.dp).testTag("profile.lock.message")) }
            Spacer(Modifier.height(8.dp))
            Button(
                enabled = pin.length >= ProfileLockService.MIN_DIGITS,
                modifier = Modifier.testTag("profile.lock.unlock"),
                onClick = {
                    val result = ProfileManager.verifyPin(activity, pin, record.id)
                    if (result == PinVerifyResult.Ok) { ProfileGate.unlock(); onUnlocked() }
                    else { message = pinFailureText(result); pin = "" }
                }
            ) { Text(L10n.t("profile_unlock_button")) }
            if (biometricsOn) {
                TextButton(onClick = { tryBiometrics() }, modifier = Modifier.testTag("profile.lock.biometrics")) {
                    Text(L10n.t("profile_use_biometrics"))
                }
            }
            if (registry.profiles.size > 1) {
                TextButton(onClick = { showPicker = true }, modifier = Modifier.testTag("profile.lock.other")) {
                    Text(L10n.t("profile_other_user"))
                }
            }
        }
    }
    if (showPicker) ProfilePickerDialog(activity) { showPicker = false }
}

/** 登入時發現這個 Google 帳號已經綁在別的使用者：告訴使用者一次。 */
@Composable
fun ProfileGoogleConflictDialog() {
    val owner by ProfileManager.googleConflict.collectAsState()
    owner?.let { name ->
        AlertDialog(
            onDismissRequest = { ProfileManager.googleConflict.value = null },
            text = { Text(L10n.f("profile_google_bound_elsewhere", name)) },
            confirmButton = {
                TextButton(onClick = { ProfileManager.googleConflict.value = null }) { Text(L10n.t("confirm")) }
            }
        )
    }
}
