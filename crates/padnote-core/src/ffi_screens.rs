//! 畫面的資訊架構：每個畫面有哪些區塊、哪些控制項、順序為何。
//!
//! # 為什麼在核心（這是整個對齊計劃的地基）
//!
//! 「Android 的版面跟 Apple 差太多」已經修過兩次，兩次都是**照清單補畫面**，
//! 補完沒有東西守著它 —— 於是 Apple 每加一個功能（頁面規格、搬頁、逐頁樣板
//! …），差距就重新拉開一次。使用者第三次回報的還是同一句話。
//!
//! 版面（`ffi_guides`）、紙張（`ffi_paper`）、斷點（`ffi_layout`）、
//! 工具列（`ffi_ui`）都已經下沉到核心，唯獨**畫面本身**還是兩邊各寫各的。
//! 這個模組補上那一塊：畫面的資訊架構變成一份資料，兩端照著長，
//! 兩端各有一個測試比對實際畫出來的控制項與這份資料 ——
//! 「Apple 加了一個控制項而 Android 沒加」因此會在 CI 上紅。
//!
//! # 這份規格**不**描述什麼
//!
//! 不描述像素、顏色、圓角、字級。那是設計代幣的事（`DesignSystem`），
//! 而且逐像素相同在兩個平台上做不到也不該做：Android 有系統返回鍵、
//! Material 的對話框行為、不同的字體度量。
//!
//! 它描述的是**資訊架構**：有什麼、什麼順序、叫什麼名字（語系鍵）。
//! 這一層必須完全一致 —— 使用者說的「差異太大」指的就是這一層。
//!
//! # 平台差異怎麼表達
//!
//! [`FfiPlatforms`] 一欄。刻意的平台差異（iCloud 只在 Apple、
//! 返回鍵只在 Android）寫成 `AppleOnly` / `AndroidOnly` 並**留在規格裡**，
//! 而不是從規格中消失 —— 消失的話就分不出「刻意的差異」與「漏做」。

/// 這個控制項在哪些平台上要存在。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiPlatforms {
    /// 兩端都必須有。**絕大多數應該是這一種。**
    Both,
    /// 只有 Apple 有，而且那是刻意的（平台專有能力）。
    AppleOnly,
    /// 只有 Android 有，而且那是刻意的（平台慣例或專有能力）。
    AndroidOnly,
}

/// 控制項的種類。測試只比對種類，不比對長相 ——
/// 同一個「選擇器」在 Apple 是 `Picker`、在 Android 是 `DropdownMenu`，
/// 那是 L3 外觀層的事。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiControlKind {
    /// 按下去會發生一件事。
    Button,
    /// 可輸入的欄位。
    Field,
    /// 從數個值裡挑一個。
    Picker,
    /// 開關。
    Toggle,
    /// 連續值。
    Slider,
    /// 一張卡片（可點，通常帶標題與說明）。
    Card,
    /// 一組重複的項目（筆記卡片格線、錄音列表、頁面縮圖）。
    List,
    /// 純顯示的文字（標題、狀態、版本號）。
    Label,
    /// 畫布本身。
    Canvas,
}

/// 一個控制項。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiControlSpec {
    /// 穩定識別字。**平台要把它放進 accessibility identifier / testTag**，
    /// 對照測試靠它認人。命名一律 `畫面.區塊.控制項`。
    pub id: String,
    pub kind: FfiControlKind,
    /// 顯示文字的語系鍵。空字串代表這個控制項沒有文字（純圖示或畫布）。
    ///
    /// 這一欄也是閘門的一部分：兩端顯示的字必須來自同一個鍵，
    /// 否則同一顆按鈕在兩台裝置上寫著不一樣的字（實際發生過：
    /// Android 的雲端同步說明誤用了另一條路的 `sync_explainer`）。
    pub label_key: String,
    pub platforms: FfiPlatforms,
    /// 依狀態才出現（例如「登出」只在已登入時）。
    /// 對照測試對 optional 的項目只檢查「出現時 id 要對」，不檢查它必須在。
    pub optional: bool,
}

/// 畫面裡的一個區塊。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSectionSpec {
    pub id: String,
    /// 區塊標題的語系鍵；空字串代表這個區塊不顯示標題。
    pub title_key: String,
    pub controls: Vec<FfiControlSpec>,
}

/// 一個畫面。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiScreenSpec {
    pub id: String,
    pub title_key: String,
    /// **順序就是畫面上由上而下的順序**，不是集合。
    pub sections: Vec<FfiSectionSpec>,
}

fn c(id: &str, kind: FfiControlKind, label_key: &str) -> FfiControlSpec {
    FfiControlSpec {
        id: id.to_string(),
        kind,
        label_key: label_key.to_string(),
        platforms: FfiPlatforms::Both,
        optional: false,
    }
}

fn opt(mut spec: FfiControlSpec) -> FfiControlSpec {
    spec.optional = true;
    spec
}

fn only(mut spec: FfiControlSpec, p: FfiPlatforms) -> FfiControlSpec {
    spec.platforms = p;
    spec
}

fn section(id: &str, title_key: &str, controls: Vec<FfiControlSpec>) -> FfiSectionSpec {
    FfiSectionSpec {
        id: id.to_string(),
        title_key: title_key.to_string(),
        controls,
    }
}

/// 目前納入閘門的畫面。
///
/// **刻意從三個開始**：首頁、編輯器、新增筆記本 —— 使用者每天會看幾十次
/// 的三個畫面。面板與對話框在後面的階段逐一納入，每納入一個就鎖住一個。
/// 一次把二十幾個畫面全寫進來的話，測試會一次全紅，而全紅的閘門等於沒有閘門。
#[uniffi::export]
pub fn screen_ids() -> Vec<String> {
    vec![
        "home".to_string(),
        "editor".to_string(),
        "new_notebook".to_string(),
        "toolbar".to_string(),
    ]
}

/// 一個畫面的規格。認不得的 id 回一個空的畫面（而不是 panic）——
/// 平台層拿到空的會在測試裡顯示「這個畫面沒有規格」，比整個 App 當掉好。
#[uniffi::export]
pub fn screen_spec(id: String) -> FfiScreenSpec {
    match id.as_str() {
        "home" => home_spec(),
        "editor" => editor_spec(),
        "new_notebook" => new_notebook_spec(),
        "toolbar" => toolbar_spec(),
        _ => FfiScreenSpec {
            id,
            title_key: String::new(),
            sections: vec![],
        },
    }
}

/// 扁平化的控制項 id，依畫面順序。對照測試最常用的就是這一個。
#[uniffi::export]
pub fn screen_control_ids(id: String) -> Vec<String> {
    screen_spec(id)
        .sections
        .into_iter()
        .flat_map(|s| s.controls)
        .map(|c| c.id)
        .collect()
}

/// 某個平台上**必須存在**的控制項 id（排除 optional 與另一個平台專有的）。
///
/// `apple` 為 true 時回 Apple 端的必備清單，否則回 Android 的。
#[uniffi::export]
pub fn screen_required_control_ids(id: String, apple: bool) -> Vec<String> {
    screen_spec(id)
        .sections
        .into_iter()
        .flat_map(|s| s.controls)
        .filter(|c| !c.optional)
        .filter(|c| match c.platforms {
            FfiPlatforms::Both => true,
            FfiPlatforms::AppleOnly => apple,
            FfiPlatforms::AndroidOnly => !apple,
        })
        .map(|c| c.id)
        .collect()
}

// ────────────────────────────── 首頁 ──────────────────────────────

fn home_spec() -> FfiScreenSpec {
    use FfiControlKind::*;
    FfiScreenSpec {
        id: "home".to_string(),
        title_key: "app_name".to_string(),
        sections: vec![
            section(
                "home.header",
                "",
                vec![
                    c("home.title", Label, ""),
                    c("home.language", Button, "language"),
                ],
            ),
            section(
                "home.identity",
                "",
                vec![
                    c("home.identity.card", Card, "identity_desc_short"),
                    c("home.identity.edit", Button, "edit_identity"),
                ],
            ),
            section(
                "home.search",
                "",
                vec![c("home.search.field", Field, "search_placeholder")],
            ),
            section(
                "home.actions",
                "",
                vec![
                    c("home.action.new_note", Card, "new_note"),
                    c("home.action.record", Card, "start_recording"),
                    c("home.action.assets", Card, "asset_library"),
                    c("home.action.import", Card, "import_note"),
                ],
            ),
            section(
                "home.continue",
                "continue",
                vec![
                    c("home.continue.show_all", Button, "show_all"),
                    opt(c("home.continue.unhide", Button, "unhide_items")),
                    c("home.continue.list", List, ""),
                ],
            ),
            section(
                "home.recordings",
                "recent_recordings",
                vec![
                    c("home.recordings.show_all", Button, "show_all"),
                    opt(c("home.recordings.unhide", Button, "unhide_items")),
                    // Apple 專有：它有**一個**共用的錄音資料夾可以在
                    // Finder／檔案 App 裡打開。Android 的錄音住在每一本筆記的
                    // `media/audio` 裡，沒有單一資料夾可開 —— 硬做一顆按鈕
                    // 只會打開一個空目錄。
                    only(
                        c("home.recordings.open_folder", Button, "open_record_folder"),
                        FfiPlatforms::AppleOnly,
                    ),
                    c("home.recordings.list", List, ""),
                ],
            ),
            section(
                "home.notebooks",
                "all_notebooks",
                vec![
                    c("home.notebooks.sort", Picker, "sort_by"),
                    c("home.notebooks.rename_root", Button, "edit_root_folder"),
                    c("home.notebooks.new_folder", Button, "new_subfolder"),
                    opt(c("home.notebooks.unhide", Button, "unhide_items")),
                    c("home.notebooks.list", List, ""),
                ],
            ),
            section(
                "home.data",
                "data_and_sync",
                vec![
                    c("home.cloud.card", Card, "cloud_sync_explainer"),
                    c("home.cloud.signin", Button, "sign_in_google"),
                    opt(c("home.cloud.sync_now", Button, "sync_now")),
                    opt(c("home.cloud.signout", Button, "sign_out")),
                    c("home.data.backup", Card, "backup_create"),
                    c("home.data.restore", Card, "backup_restore"),
                    c("home.data.folder", Card, "sync_choose_folder"),
                ],
            ),
            section(
                "home.documents",
                "help_and_legal",
                vec![
                    c("home.docs.manual", Card, "user_manual"),
                    c("home.docs.privacy", Card, "privacy_policy"),
                ],
            ),
            section(
                "home.footer",
                "",
                vec![
                    c("home.version", Label, "version_number"),
                    c("home.diagnostics", Button, "version_number"),
                ],
            ),
        ],
    }
}

// ───────────────────────────── 編輯器 ─────────────────────────────

fn editor_spec() -> FfiScreenSpec {
    use FfiControlKind::*;
    FfiScreenSpec {
        id: "editor".to_string(),
        title_key: "notebook".to_string(),
        sections: vec![
            // 頂列：左到右，照 Apple 緊湊模式的實際順序。
            // （寬螢幕是同一組項目攤開，不是另一組功能。）
            section(
                "editor.topbar",
                "",
                vec![
                    // Android 另外接系統返回鍵（`BackHandler`）—— 那是平台慣例，
                    // 拿掉等於這個 App 在 Android 上壞掉；Apple 沒有對應物。
                    only(
                        c("editor.system_back", Button, "back"),
                        FfiPlatforms::AndroidOnly,
                    ),
                    c("editor.home", Button, "home"),
                    c("editor.sidebar_toggle", Button, "page_structure"),
                    c("editor.mode", Picker, "editor_mode"),
                    c("editor.title", Button, "note_title"),
                    c("editor.page.prev", Button, "previous_page"),
                    c("editor.page.indicator", Label, ""),
                    c("editor.page.next", Button, "next_page"),
                    c("editor.page.add", Button, "add_page"),
                    c("editor.page.display_mode", Button, "page_mode"),
                    c("editor.page_format", Picker, "page_format"),
                    c("editor.guide_palette", Picker, "guide_palette"),
                    c("editor.more", Button, "more_tools"),
                    c("editor.record", Button, "start_recording"),
                    c("editor.share", Button, "export_and_print"),
                ],
            ),
            // 插入選單。十三項在 TODO 的落差盤點裡已記為「兩端都有」，
            // 這裡把它固定下來，之後誰多加一項都逃不過閘門。
            section(
                "editor.insert",
                "insert_object",
                vec![
                    c("editor.insert.assets", Button, "asset_library"),
                    // 規格原本漏了這一項 —— Apple 有、Android 沒有，
                    // 而對照閘門是綠的（它只檢查規格裡列出來的）。
                    // 漏一項的代價就是一個平台少一整個功能，沒有人會發現。
                    c("editor.insert.stickers", Button, "sticker_library"),
                    c("editor.insert.audio", Button, "insert_audio"),
                    c("editor.insert.image", Button, "insert_image"),
                    c("editor.insert.math", Button, "math_calc"),
                    c("editor.insert.chart", Button, "chart_studio"),
                    c("editor.insert.table", Button, "table_studio"),
                    c("editor.insert.shape", Button, "shape_studio"),
                    c("editor.insert.model3d", Button, "insert_3d"),
                    c("editor.insert.theme_tools", Button, "theme_tools"),
                    // 「自訂工具列」的入口（S-261）。放在這一組是因為它
                    // 與其他項目一樣住在「更多」選單裡 —— 而選單內容不會
                    // 出現在 XCUITest 的無障礙樹裡，所以兩端的畫面稽核都
                    // 看不到它，只有靜態的對照閘門掃得到。
                    c("editor.customize_toolbar", Button, "customize_toolbar"),
                    c("editor.insert.refine_sketch", Button, "refine_sketch"),
                    c("editor.insert.comment_pin", Button, "add_comment_pin"),
                    c("editor.insert.collaborate", Button, "collaborate"),
                    c("editor.insert.recognize", Button, "recognize_handwriting"),
                    c("editor.insert.ai_summary", Button, "ai_summary"),
                ],
            ),
            section(
                "editor.export",
                "export_and_print",
                vec![
                    c("editor.export.pdf", Button, "export_pdf"),
                    c("editor.export.image", Button, "export_image"),
                    c("editor.export.print", Button, "print_note"),
                    c("editor.export.share", Button, "share_note"),
                ],
            ),
            // 第二排：手寫模式。九個工具的順序與 `EditorToolType` 一致。
            section(
                "editor.inktools",
                "",
                vec![
                    c("editor.ink.pen", Button, "tool_pen"),
                    c("editor.ink.ballpoint", Button, "tool_ballpoint"),
                    c("editor.ink.brush", Button, "tool_brush"),
                    c("editor.ink.marker", Button, "tool_marker"),
                    c("editor.ink.highlighter", Button, "tool_highlighter"),
                    c("editor.ink.pencil", Button, "tool_pencil"),
                    c("editor.ink.watercolor", Button, "tool_watercolor"),
                    c("editor.ink.eraser", Button, "tool_eraser"),
                    c("editor.ink.lasso", Button, "tool_lasso"),
                    // 兩端都有這一支，規格卻一直沒寫進來 —— 於是對照閘門
                    // 從來沒檢查過它（S-261 稽核到的）。
                    c("editor.ink.maskingTape", Button, "tool_masking_tape"),
                    c("editor.ink.width", Slider, "stroke_width"),
                    c("editor.ink.palette", Picker, "color"),
                    c("editor.ink.undo", Button, "undo"),
                    c("editor.ink.redo", Button, "redo"),
                    c("editor.ink.clear", Button, "clear_page"),
                ],
            ),
            // 第二排：打字模式（Word 風格工具列 Ribbon）。
            section(
                "editor.texttools",
                "",
                vec![
                    c("editor.text.add_box", Button, "add_text_box"),
                    c("editor.text.studio", Button, "tool_text"),
                    c("editor.text.bold", Button, "text_bold"),
                    c("editor.text.italic", Button, "text_italic"),
                    c("editor.text.underline", Button, "text_underline"),
                    c("editor.text.align_left", Button, "align_left"),
                    c("editor.text.align_center", Button, "align_center_h"),
                    c("editor.text.align_right", Button, "align_right"),
                    c("editor.text.snap_grid", Button, "snap_to_grid"),
                    c("editor.text.layer_forward", Button, "layer_bring_forward"),
                    c("editor.text.layer_backward", Button, "layer_send_backward"),
                    c("editor.text.symbols", Button, "special_symbols"),
                    c("editor.text.select", Button, "marquee_select"),
                    c("editor.text.link", Button, "insert_link"),
                    c("editor.text.undo", Button, "undo"),
                    c("editor.text.redo", Button, "redo"),
                ],
            ),
            section(
                "editor.sidebar",
                "page_structure",
                vec![
                    c("editor.sidebar.tab.pages", Button, "structure_pages"),
                    c("editor.sidebar.tab.folders", Button, "structure_folders"),
                    c("editor.sidebar.list", List, ""),
                    c("editor.sidebar.thumb_smaller", Button, "thumbnail_smaller"),
                    c("editor.sidebar.thumb_larger", Button, "thumbnail_larger"),
                ],
            ),
            section("editor.canvas", "", vec![c("editor.canvas", Canvas, "")]),
        ],
    }
}

// ────────────────────────── 新增筆記本 ──────────────────────────

fn new_notebook_spec() -> FfiScreenSpec {
    use FfiControlKind::*;
    FfiScreenSpec {
        id: "new_notebook".to_string(),
        title_key: "new_notebook".to_string(),
        sections: vec![
            section(
                "new_notebook.header",
                "",
                vec![
                    c("new_notebook.cancel", Button, "cancel"),
                    c("new_notebook.confirm", Button, "confirm"),
                ],
            ),
            section(
                "new_notebook.title",
                "note_title",
                vec![c("new_notebook.title.field", Field, "note_title")],
            ),
            section(
                "new_notebook.paper",
                "select_template",
                vec![
                    c("new_notebook.paper.themes", Picker, "select_template"),
                    c("new_notebook.paper.list", List, ""),
                    opt(c("new_notebook.paper.content", Picker, "paper_content")),
                    c("new_notebook.palette", Picker, "guide_palette"),
                ],
            ),
            section(
                "new_notebook.recent",
                "recent_templates",
                vec![opt(c("new_notebook.recent.list", List, ""))],
            ),
            section(
                "new_notebook.document",
                "document_template",
                vec![
                    c("new_notebook.document.current", Label, "doc_template"),
                    c("new_notebook.document.tree", List, ""),
                ],
            ),
        ],
    }
}

// ───────────────────────── 自訂工具列（S-261）─────────────────────────

/// 「自訂工具列」設定畫面。
///
/// 每一個開關的 id 是 `toolbar.tool.` 接上該工具在編輯器裡的識別字尾碼 ——
/// 例如編輯器的 `editor.ink.pen` 對應這裡的 `toolbar.tool.pen`。
/// 兩邊用同一個字尾，對照閘門紅掉時一眼看得出是哪一支工具，
/// 而不是「toolbar 第 7 個開關」。
fn toolbar_spec() -> FfiScreenSpec {
    use FfiControlKind::*;
    let tools = padnote_toolbar::tools::all_tools()
        .into_iter()
        .map(|t| {
            let suffix = t
                .parity_identifier()
                .rsplit('.')
                .next()
                .expect("識別字一定有字尾");
            c(&format!("toolbar.tool.{suffix}"), Toggle, ui_label_key(t))
        })
        .collect::<Vec<_>>();

    FfiScreenSpec {
        id: "toolbar".to_string(),
        title_key: "customize_toolbar".to_string(),
        sections: vec![
            section(
                "toolbar.header",
                "",
                vec![
                    c("toolbar.hint", Label, ""),
                    c("toolbar.reset", Button, "toolbar_reset"),
                ],
            ),
            section("toolbar.tools", "customize_toolbar", tools),
        ],
    }
}

/// 工具在**介面字串表**（`i18n/ui-strings.json`）裡的鍵。
///
/// 與核心 `Tool::label_key` 是兩張不同的表：核心那張給 Rust 端用，
/// 這張是兩個平台的畫面在用的。設定畫面上的字必須與編輯器工具列上的字
/// **逐字相同** —— 使用者要靠那行字認出自己在關哪一顆按鈕。
fn ui_label_key(t: padnote_toolbar::Tool) -> &'static str {
    use padnote_toolbar::Tool::*;
    match t {
        Pen => "tool_pen",
        BallPoint => "tool_ballpoint",
        Brush => "tool_brush",
        Marker => "tool_marker",
        Highlighter => "tool_highlighter",
        Pencil => "tool_pencil",
        Watercolor => "tool_watercolor",
        Eraser => "tool_eraser",
        Lasso => "tool_lasso",
        MaskingTape => "tool_masking_tape",
        Undo => "undo",
        Redo => "redo",
        ClearPage => "clear_page",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// id 必須唯一 —— 重複的 id 會讓對照測試「找到了」卻是別的控制項。
    #[test]
    fn control_ids_are_unique_within_a_screen() {
        for id in screen_ids() {
            let ids = screen_control_ids(id.clone());
            let mut sorted = ids.clone();
            sorted.sort();
            sorted.dedup();
            assert_eq!(sorted.len(), ids.len(), "{id} 有重複的控制項 id");
        }
    }

    /// id 必須以畫面 id 開頭。命名一亂，測試失敗時就看不出是哪個畫面。
    #[test]
    fn control_ids_are_namespaced_by_screen() {
        for id in screen_ids() {
            for cid in screen_control_ids(id.clone()) {
                assert!(cid.starts_with(&format!("{id}.")), "{cid} 不屬於 {id}");
            }
        }
    }

    /// 除了純顯示與畫布，每個控制項都要有語系鍵 ——
    /// 沒有鍵的按鈕就是寫死的字，而寫死的字不會被翻譯（"edit" 那顆就是這樣）。
    #[test]
    fn interactive_controls_carry_a_label_key() {
        for id in screen_ids() {
            for section in screen_spec(id.clone()).sections {
                for ctl in section.controls {
                    let needs_label = !matches!(
                        ctl.kind,
                        FfiControlKind::Label | FfiControlKind::Canvas | FfiControlKind::List
                    );
                    if needs_label {
                        assert!(!ctl.label_key.is_empty(), "{} 沒有語系鍵", ctl.id);
                    }
                }
            }
        }
    }

    /// 必備清單不得包含另一個平台專有的項目。
    #[test]
    fn required_lists_exclude_the_other_platform() {
        for id in screen_ids() {
            let apple = screen_required_control_ids(id.clone(), true);
            let android = screen_required_control_ids(id.clone(), false);
            for section in screen_spec(id.clone()).sections {
                for ctl in section.controls {
                    match ctl.platforms {
                        FfiPlatforms::AppleOnly => assert!(!android.contains(&ctl.id)),
                        FfiPlatforms::AndroidOnly => assert!(!apple.contains(&ctl.id)),
                        FfiPlatforms::Both => {
                            if !ctl.optional {
                                assert!(apple.contains(&ctl.id) && android.contains(&ctl.id));
                            }
                        }
                    }
                }
            }
        }
    }

    /// 認不得的畫面回空的，不 panic。
    #[test]
    fn unknown_screen_is_empty_not_a_crash() {
        assert!(screen_spec("nope".into()).sections.is_empty());
    }
}
