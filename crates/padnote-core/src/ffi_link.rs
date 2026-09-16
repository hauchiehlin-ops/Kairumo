//! 連結卡片的中繼資料解析（兩平台共用）。
//!
//! # 為什麼在核心
//!
//! Apple 端原本自己解析，Android 沒有這個功能。照著抄一份過去的話，兩邊的
//! 正規表示式遲早會分岔 —— 而症狀是「同一個網址在 iPad 上抓得到標題、
//! 在 Android 上抓不到」，那種差異沒有人會想去查。
//!
//! HTTP 仍然由平台做（與 `ffi_gdrive` 同一個分工）：核心只收 HTML 字串。
//!
//! # 抓不到就回主機名，**不要編**
//!
//! Apple 端原本對 `apple.com`、`github.com`、`wikipedia.org` 內建了一組
//! 寫死的標題與描述（而且是寫死的繁體中文）。那是**捏造的中繼資料**：
//! 網路抓不到時，使用者會得到一段看起來像真的、實際上是我們編的網站簡介，
//! 而且不管他的介面語言是什麼都是中文。
//!
//! 抓不到就用主機名 —— 那至少是真的。

/// 一個連結的中繼資料。
#[derive(Clone, Debug, PartialEq, Eq, uniffi::Record)]
pub struct FfiLinkMetadata {
    /// 正規化之後的網址。
    pub url: String,
    pub title: String,
    pub description: String,
    pub site_name: String,
}

/// 補上通訊協定、去掉前後空白。
///
/// 使用者貼進來的十次有九次是 `example.com` 而不是 `https://example.com`。
/// 不補的話後面每一步都會失敗，而錯誤訊息會是「無效的網址」——
/// 對一個看起來完全正常的網址這麼說，使用者只會覺得程式壞了。
#[uniffi::export]
pub fn link_normalize_url(raw: String) -> String {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    let lower = trimmed.to_lowercase();
    if lower.starts_with("http://") || lower.starts_with("https://") {
        trimmed.to_string()
    } else {
        format!("https://{trimmed}")
    }
}

/// 從網址取出主機名。取不到回空字串。
#[uniffi::export]
pub fn link_host(url: String) -> String {
    let without_scheme = url
        .trim()
        .trim_start_matches("https://")
        .trim_start_matches("http://");
    let host = without_scheme
        .split(['/', '?', '#'])
        .next()
        .unwrap_or("")
        // 去掉埠號與使用者資訊。
        .rsplit('@')
        .next()
        .unwrap_or("")
        .split(':')
        .next()
        .unwrap_or("");
    host.to_string()
}

/// 解析 HTML 的中繼資料。
///
/// `html` 可以是空字串（抓取失敗）—— 那時整份結果退回主機名，
/// **不會編造任何東西**。
#[uniffi::export]
pub fn link_parse_metadata(html: String, url: String) -> FfiLinkMetadata {
    let url = link_normalize_url(url);
    let host = link_host(url.clone());
    // `www.` 對使用者沒有意義，顯示時拿掉。
    let bare_host = host.strip_prefix("www.").unwrap_or(&host).to_string();

    let title = meta_content(&html, "og:title")
        .or_else(|| title_tag(&html))
        .unwrap_or_else(|| bare_host.clone());
    let description = meta_content(&html, "og:description")
        .or_else(|| meta_content(&html, "description"))
        // 抓不到描述就用網址本身。編一段簡介比留白更糟 ——
        // 使用者沒有辦法分辨哪一段是真的。
        .unwrap_or_else(|| url.clone());
    let site_name = meta_content(&html, "og:site_name").unwrap_or_else(|| bare_host.clone());

    FfiLinkMetadata {
        url,
        title: decode_entities(title.trim()),
        description: decode_entities(description.trim()),
        site_name: decode_entities(site_name.trim()),
    }
}

/// 找 `<meta>` 的 `content`，`key` 可以是 `property` 或 `name` 的值。
///
/// **屬性順序兩種都要認得。** 真實世界的 HTML 兩種都有：
/// `<meta property="og:title" content="…">` 與
/// `<meta content="…" property="og:title">`。只認一種的話，
/// 有些網站永遠抓不到標題，而那看起來像「這個網站擋我們」。
fn meta_content(html: &str, key: &str) -> Option<String> {
    let lower = html.to_lowercase();
    let needle_prop = format!("\"{key}\"");
    let needle_prop_single = format!("'{key}'");

    let mut cursor = 0usize;
    while let Some(rel) = lower[cursor..].find("<meta") {
        let start = cursor + rel;
        let end = lower[start..].find('>').map(|e| start + e)?;
        let tag = &html[start..end];
        let tag_lower = &lower[start..end];
        cursor = end + 1;

        // 這個 meta 是不是我們要的那一個。
        let is_match = (tag_lower.contains("property=") || tag_lower.contains("name="))
            && (tag_lower.contains(&needle_prop) || tag_lower.contains(&needle_prop_single));
        if !is_match {
            continue;
        }
        if let Some(value) = attribute(tag, "content")
            && !value.trim().is_empty()
        {
            return Some(value);
        }
    }
    None
}

/// 取出 `<title>` 的內容。
fn title_tag(html: &str) -> Option<String> {
    let lower = html.to_lowercase();
    let open = lower.find("<title")?;
    let content_start = open + lower[open..].find('>')? + 1;
    let close = lower[content_start..].find("</title>")? + content_start;
    let text = html[content_start..close].trim();
    if text.is_empty() {
        None
    } else {
        Some(text.to_string())
    }
}

/// 取出標籤裡某個屬性的值。單引號與雙引號都要認得。
fn attribute(tag: &str, name: &str) -> Option<String> {
    let lower = tag.to_lowercase();
    let key = format!("{name}=");
    let at = lower.find(&key)? + key.len();
    let rest = &tag[at..];
    let quote = rest.chars().next()?;
    if quote != '"' && quote != '\'' {
        return None;
    }
    let value_start = quote.len_utf8();
    let end = rest[value_start..].find(quote)? + value_start;
    Some(rest[value_start..end].to_string())
}

/// 解掉最常見的幾個 HTML 實體。
///
/// `&amp;` 不還原的話，標題會變成「Tom &amp;amp; Jerry」——
/// 使用者看得懂那是壞掉的，但修不了。
///
/// **`&amp;` 必須最後處理**：先還原它的話，`&amp;lt;` 會先變成 `&lt;`
/// 再變成 `<`，等於把原文裡刻意跳脫的東西解開兩次。
fn decode_entities(text: &str) -> String {
    text.replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&apos;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_bare_domain_gets_https() {
        // 使用者貼進來的十次有九次是這樣。
        assert_eq!(
            link_normalize_url("example.com".into()),
            "https://example.com"
        );
        assert_eq!(
            link_normalize_url("  https://example.com  ".into()),
            "https://example.com"
        );
        assert_eq!(
            link_normalize_url("HTTP://example.com".into()),
            "HTTP://example.com"
        );
        assert_eq!(link_normalize_url("   ".into()), "");
    }

    #[test]
    fn the_host_is_extracted_without_port_or_path() {
        assert_eq!(
            link_host("https://example.com/a/b?c=d".into()),
            "example.com"
        );
        assert_eq!(
            link_host("https://example.com:8443/x".into()),
            "example.com"
        );
        assert_eq!(
            link_host("https://user@example.com/x".into()),
            "example.com"
        );
    }

    #[test]
    fn open_graph_wins_over_the_title_tag() {
        let html = r#"<html><head>
            <title>後備標題</title>
            <meta property="og:title" content="正式標題">
        </head></html>"#;
        let meta = link_parse_metadata(html.into(), "https://example.com".into());
        assert_eq!(meta.title, "正式標題");
    }

    #[test]
    fn the_title_tag_is_the_fallback() {
        let html = "<html><head><title>只有這個</title></head></html>";
        let meta = link_parse_metadata(html.into(), "https://example.com".into());
        assert_eq!(meta.title, "只有這個");
    }

    #[test]
    fn attributes_in_either_order_are_understood() {
        // **真實世界的 HTML 兩種都有。** 只認一種的話，有些網站永遠抓不到
        // 標題，而那看起來像「這個網站擋我們」。
        let a = r#"<meta property="og:title" content="甲">"#;
        let b = r#"<meta content="乙" property="og:title">"#;
        assert_eq!(
            link_parse_metadata(a.into(), "https://e.com".into()).title,
            "甲"
        );
        assert_eq!(
            link_parse_metadata(b.into(), "https://e.com".into()).title,
            "乙"
        );
    }

    #[test]
    fn single_quotes_work_too() {
        let html = "<meta property='og:title' content='單引號'>";
        assert_eq!(
            link_parse_metadata(html.into(), "https://e.com".into()).title,
            "單引號"
        );
    }

    #[test]
    fn nothing_fetched_falls_back_to_the_host_and_invents_nothing() {
        // **這一條守的是最重要的行為。** 舊版對 apple.com / github.com /
        // wikipedia.org 內建了一組寫死的標題與描述（而且是寫死的繁體中文）。
        // 那是捏造的中繼資料：網路抓不到時，使用者會得到一段看起來像真的、
        // 實際上是我們編的網站簡介。
        let meta = link_parse_metadata(String::new(), "https://www.apple.com".into());
        assert_eq!(meta.title, "apple.com", "抓不到就用主機名");
        assert_eq!(meta.site_name, "apple.com");
        assert_eq!(
            meta.description, "https://www.apple.com",
            "描述退回網址，不編"
        );
        assert!(!meta.description.contains("探索"), "不可以有捏造的簡介");
    }

    #[test]
    fn www_is_dropped_from_the_display_name() {
        let meta = link_parse_metadata(String::new(), "https://www.example.com".into());
        assert_eq!(meta.site_name, "example.com");
    }

    #[test]
    fn html_entities_are_decoded() {
        let html = r#"<meta property="og:title" content="Tom &amp; Jerry &quot;1940&quot;">"#;
        assert_eq!(
            link_parse_metadata(html.into(), "https://e.com".into()).title,
            "Tom & Jerry \"1940\""
        );
    }

    #[test]
    fn an_escaped_entity_is_not_decoded_twice() {
        // `&amp;lt;` 在原文裡就是要顯示成 `&lt;`，不是 `<`。
        // 先還原 `&amp;` 的話會解開兩次。
        let html = r#"<meta property="og:title" content="&amp;lt;tag&amp;gt;">"#;
        assert_eq!(
            link_parse_metadata(html.into(), "https://e.com".into()).title,
            "&lt;tag&gt;"
        );
    }

    #[test]
    fn an_empty_content_attribute_does_not_win() {
        // 空的 og:title 要讓位給 <title>，不然標題會是一片空白。
        let html = r#"<meta property="og:title" content=""><title>真的標題</title>"#;
        assert_eq!(
            link_parse_metadata(html.into(), "https://e.com".into()).title,
            "真的標題"
        );
    }

    #[test]
    fn a_meta_description_is_used_when_open_graph_is_absent() {
        let html = r#"<meta name="description" content="一段描述">"#;
        assert_eq!(
            link_parse_metadata(html.into(), "https://e.com".into()).description,
            "一段描述"
        );
    }
}
