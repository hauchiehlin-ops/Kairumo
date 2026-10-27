//! 頁面上的物件與手寫筆跡誰疊在誰上面。
//!
//! # 原則
//!
//! 這是電子筆記：使用者**在東西上面寫字**。所以「標註用的內容」——手寫
//! 筆跡、打字的文字方塊、討論圖釘——預設在最上層；被標註的素材（插入的
//! PDF 頁面、圖片、圖表、表格、形狀、3D、連結卡片、錄音卡片）預設在筆跡
//! **下方**。
//!
//! 在此之前兩端的預設剛好相反：所有物件一律疊在筆跡上面，只有使用者手動
//! 「移到筆跡下方」的才在下面。插一頁 PDF 再拿筆畫重點，畫出來的線全部
//! 被那張整頁的圖蓋住 —— 看起來像「在 PDF 上不能寫字」。
//!
//! # 為什麼在核心
//!
//! 同一本筆記在 iPad 與 Android 上要疊得一模一樣。這條規則原本是兩端各自
//! 寫死在畫布的 z 值裡（Apple 的視圖樹順序、Android 的 `10f`／`200f`），
//! 改一邊就會跟另一邊不一樣。現在兩端都只問這裡。
//!
//! # 兩份清單
//!
//! 使用者仍然可以把任何一個物件搬到筆跡的另一側。記錄方式：
//!
//! - `under`：明確放在筆跡下方的物件（沿用既有的 `underInkObjectIdsByPage`）。
//! - `over`：明確放在筆跡上方的物件（`overInkObjectIdsByPage`）。
//!
//! 放到下方時**一定**寫進 `under`，即使那個型別預設就在下方 —— 舊版 App
//! 只認得 `under`、而且把其餘物件都畫在筆跡上面；寫進去之後舊版看到的
//! 結果與新版相同。`over` 只在「預設在下方、被搬到上方」時才需要。
//!
//! 兩份都有（同步合併的結果）時以 `over` 為準：那只會發生在使用者
//! 明確要求「放到上面」之後，而預設在上方的型別根本不會被寫進 `over`。

use std::collections::HashSet;

/// 頁面上可以疊放的物件種類。
///
/// PDF 頁面、貼紙、數學卡片都是**圖片物件**（`Image`），不是另外的種類 ——
/// 它們在兩端都走圖片的儲存與同步路徑。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug, uniffi::Enum)]
pub enum FfiLayerKind {
    Image,
    Shape,
    Table,
    Chart,
    Model3d,
    Link,
    Audio,
    Text,
    Pin,
    /// 紙膠帶。
    Tape,
}

/// 物件相對於手寫筆跡的那一層。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiInkPlane {
    /// 在筆跡下方：筆跡畫在它上面。
    BelowInk,
    /// 在筆跡上方：它蓋住筆跡。
    AboveInk,
}

/// 一個物件：id 加上種類。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiLayerObject {
    pub id: String,
    pub kind: FfiLayerKind,
}

/// 搬動之後的兩份清單（排序過，同一組內容每次寫出同一份，同步才不會誤判有變動）。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiInkPlaneLists {
    pub under: Vec<String>,
    pub over: Vec<String>,
}

/// 沒有任何明確設定時，這種物件在哪一層。
///
/// # 例外：文字、圖釘、紙膠帶在上方
///
/// - **文字方塊**是打字的標註，和筆跡同等級；放在上方才點得到、改得到，
///   而它預設是透明底，不會擋住底下的筆跡。
/// - **討論圖釘**是對這一頁的留言，被筆跡蓋住就找不到了。
/// - **紙膠帶**的用途就是「蓋住」——背誦時遮住答案。放到筆跡下方的話，
///   遮不住寫在下面的答案，等於失去功能。這是唯一一個刻意蓋住筆跡的物件。
#[uniffi::export]
pub fn object_default_ink_plane(kind: FfiLayerKind) -> FfiInkPlane {
    match kind {
        FfiLayerKind::Text | FfiLayerKind::Pin | FfiLayerKind::Tape => FfiInkPlane::AboveInk,
        FfiLayerKind::Image
        | FfiLayerKind::Shape
        | FfiLayerKind::Table
        | FfiLayerKind::Chart
        | FfiLayerKind::Model3d
        | FfiLayerKind::Link
        | FfiLayerKind::Audio => FfiInkPlane::BelowInk,
    }
}

/// 一個物件實際在哪一層。
#[uniffi::export]
pub fn object_ink_plane(kind: FfiLayerKind, in_under: bool, in_over: bool) -> FfiInkPlane {
    if in_over {
        FfiInkPlane::AboveInk
    } else if in_under {
        FfiInkPlane::BelowInk
    } else {
        object_default_ink_plane(kind)
    }
}

/// 沒有明確堆疊順序時，同一層裡的預設先後（數字小的在下面）。
///
/// 被標註的素材在下、標註在上：圖片（含 PDF 頁面）最底，接著形狀、表格、
/// 圖表、3D、連結、錄音卡片；文字、圖釘、紙膠帶最上面。舊筆記沒有逐頁
/// 順序時走這條路。
#[uniffi::export]
pub fn object_default_stack_rank(kind: FfiLayerKind) -> u32 {
    match kind {
        FfiLayerKind::Image => 0,
        FfiLayerKind::Shape => 1,
        FfiLayerKind::Table => 2,
        FfiLayerKind::Chart => 3,
        FfiLayerKind::Model3d => 4,
        FfiLayerKind::Link => 5,
        FfiLayerKind::Audio => 6,
        FfiLayerKind::Text => 7,
        FfiLayerKind::Pin => 8,
        FfiLayerKind::Tape => 9,
    }
}

fn lower_set(ids: &[String]) -> HashSet<String> {
    ids.iter().map(|s| s.to_lowercase()).collect()
}

/// 這一頁實際在筆跡下方的物件 id（保留傳入的大小寫，順序同 `objects`）。
///
/// id 比對不分大小寫：Apple 的 UUID 是大寫、Android 與核心是小寫，同一個
/// 物件從另一台同步過來時兩種都會出現。
#[uniffi::export]
pub fn objects_below_ink(
    objects: Vec<FfiLayerObject>,
    under: Vec<String>,
    over: Vec<String>,
) -> Vec<String> {
    let under = lower_set(&under);
    let over = lower_set(&over);
    objects
        .into_iter()
        .filter(|o| {
            let key = o.id.to_lowercase();
            object_ink_plane(o.kind, under.contains(&key), over.contains(&key))
                == FfiInkPlane::BelowInk
        })
        .map(|o| o.id)
        .collect()
}

/// 把 `moving` 這些物件搬到 `plane`，回傳更新後的兩份清單。
///
/// 不在 `moving` 裡的條目原封不動（包括這一頁已經不存在的物件 —— 清理
/// 那些是頁面重新對齊的工作，不是這裡的）。
#[uniffi::export]
pub fn move_objects_to_ink_plane(
    moving: Vec<FfiLayerObject>,
    plane: FfiInkPlane,
    under: Vec<String>,
    over: Vec<String>,
) -> FfiInkPlaneLists {
    let moving_keys: HashSet<String> = moving.iter().map(|o| o.id.to_lowercase()).collect();
    let mut under: Vec<String> = under
        .into_iter()
        .filter(|id| !moving_keys.contains(&id.to_lowercase()))
        .collect();
    let mut over: Vec<String> = over
        .into_iter()
        .filter(|id| !moving_keys.contains(&id.to_lowercase()))
        .collect();
    for object in moving {
        match plane {
            // 一律寫進 under：舊版 App 只認得這一份（見檔頭）。
            FfiInkPlane::BelowInk => under.push(object.id),
            FfiInkPlane::AboveInk => {
                if object_default_ink_plane(object.kind) == FfiInkPlane::BelowInk {
                    over.push(object.id);
                }
            }
        }
    }
    under.sort();
    under.dedup();
    over.sort();
    over.dedup();
    FfiInkPlaneLists { under, over }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn obj(id: &str, kind: FfiLayerKind) -> FfiLayerObject {
        FfiLayerObject { id: id.into(), kind }
    }

    #[test]
    fn inserted_material_defaults_below_ink_and_annotations_above() {
        for kind in [
            FfiLayerKind::Image,
            FfiLayerKind::Shape,
            FfiLayerKind::Table,
            FfiLayerKind::Chart,
            FfiLayerKind::Model3d,
            FfiLayerKind::Link,
            FfiLayerKind::Audio,
        ] {
            assert_eq!(object_default_ink_plane(kind), FfiInkPlane::BelowInk, "{kind:?}");
        }
        for kind in [FfiLayerKind::Text, FfiLayerKind::Pin, FfiLayerKind::Tape] {
            assert_eq!(object_default_ink_plane(kind), FfiInkPlane::AboveInk, "{kind:?}");
        }
    }

    #[test]
    fn a_pdf_page_image_on_a_fresh_page_is_under_the_ink() {
        // 回報的情境：插入 PDF 頁面之後畫的筆跡看不到。
        let below = objects_below_ink(vec![obj("PDF-1", FfiLayerKind::Image)], vec![], vec![]);
        assert_eq!(below, vec!["PDF-1".to_string()]);
    }

    #[test]
    fn explicit_lists_override_the_default_and_over_wins_a_conflict() {
        let objects = vec![
            obj("img", FfiLayerKind::Image),
            obj("txt", FfiLayerKind::Text),
            obj("both", FfiLayerKind::Image),
        ];
        let below = objects_below_ink(
            objects,
            vec!["txt".into(), "both".into()],
            vec!["img".into(), "both".into()],
        );
        assert_eq!(below, vec!["txt".to_string()]);
    }

    #[test]
    fn ids_match_regardless_of_case() {
        let below = objects_below_ink(
            vec![obj("ABC", FfiLayerKind::Text)],
            vec!["abc".into()],
            vec![],
        );
        assert_eq!(below, vec!["ABC".to_string()]);
        let above = objects_below_ink(vec![obj("abc", FfiLayerKind::Image)], vec![], vec!["ABC".into()]);
        assert!(above.is_empty());
    }

    #[test]
    fn moving_below_always_records_under_for_older_apps() {
        let lists = move_objects_to_ink_plane(
            vec![obj("img", FfiLayerKind::Image)],
            FfiInkPlane::BelowInk,
            vec![],
            vec!["img".into()],
        );
        assert_eq!(lists, FfiInkPlaneLists { under: vec!["img".into()], over: vec![] });
    }

    #[test]
    fn moving_above_only_records_over_when_the_default_is_below() {
        let lists = move_objects_to_ink_plane(
            vec![obj("img", FfiLayerKind::Image), obj("txt", FfiLayerKind::Text)],
            FfiInkPlane::AboveInk,
            vec!["img".into(), "txt".into(), "other".into()],
            vec![],
        );
        assert_eq!(
            lists,
            FfiInkPlaneLists { under: vec!["other".into()], over: vec!["img".into()] }
        );
        // 搬回去之後兩份清單都回到原樣。
        let back = move_objects_to_ink_plane(
            vec![obj("txt", FfiLayerKind::Text)],
            FfiInkPlane::AboveInk,
            vec![],
            vec![],
        );
        assert_eq!(back, FfiInkPlaneLists { under: vec![], over: vec![] });
    }

    #[test]
    fn stack_rank_puts_material_under_annotations() {
        assert!(object_default_stack_rank(FfiLayerKind::Image) < object_default_stack_rank(FfiLayerKind::Shape));
        assert!(object_default_stack_rank(FfiLayerKind::Audio) < object_default_stack_rank(FfiLayerKind::Text));
        assert!(object_default_stack_rank(FfiLayerKind::Text) < object_default_stack_rank(FfiLayerKind::Pin));
    }
}
