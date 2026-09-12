//! 頁面渲染快取（效能預算 J2）。
//!
//! 500 頁 PDF 不可能全部渲染在記憶體裡 —— 每頁 A4 在 2× 縮放下約 8MB，
//! 500 頁就是 4GB。策略是 **LRU + 預先渲染鄰近頁**：
//! 使用者捲動時下一頁已經備好，捲回去時上一頁還在。

use std::collections::HashMap;

/// 一張已渲染的頁面圖。縮放倍率不同視為不同項目。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub struct RenderKey {
    pub page: u32,
    /// 縮放倍率 ×100，避免浮點數當 key。
    pub scale_centi: u32,
}

impl RenderKey {
    pub fn new(page: u32, scale: f32) -> Self {
        Self {
            page,
            scale_centi: (scale * 100.0).round() as u32,
        }
    }

    pub fn scale(&self) -> f32 {
        self.scale_centi as f32 / 100.0
    }
}

#[derive(Debug)]
struct CachedPage {
    bytes: Vec<u8>,
    /// 存取序號，用於 LRU。
    last_used: u64,
}

/// 有記憶體上限的頁面快取。
#[derive(Debug)]
pub struct PageCache {
    entries: HashMap<RenderKey, CachedPage>,
    budget_bytes: usize,
    used_bytes: usize,
    tick: u64,
    hits: u64,
    misses: u64,
}

impl PageCache {
    /// `budget_bytes` 應遠低於 J5 的 400MB 記憶體預算 —— PDF 快取只是其中一部分。
    pub fn new(budget_bytes: usize) -> Self {
        Self {
            entries: HashMap::new(),
            budget_bytes,
            used_bytes: 0,
            tick: 0,
            hits: 0,
            misses: 0,
        }
    }

    pub fn used_bytes(&self) -> usize {
        self.used_bytes
    }

    pub fn len(&self) -> usize {
        self.entries.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    pub fn hit_rate(&self) -> f32 {
        let total = self.hits + self.misses;
        if total == 0 {
            return 0.0;
        }
        self.hits as f32 / total as f32
    }

    pub fn get(&mut self, key: RenderKey) -> Option<&[u8]> {
        self.tick += 1;
        let tick = self.tick;
        match self.entries.get_mut(&key) {
            Some(e) => {
                e.last_used = tick;
                self.hits += 1;
                Some(&e.bytes)
            }
            None => {
                self.misses += 1;
                None
            }
        }
    }

    /// 放入快取，必要時淘汰最久未使用的項目。
    ///
    /// 單一項目就超過預算時**不放入**而非清空整個快取 —— 後者會讓一次
    /// 極端縮放把所有既有頁面都趕走。
    pub fn put(&mut self, key: RenderKey, bytes: Vec<u8>) {
        let size = bytes.len();
        if size > self.budget_bytes {
            return;
        }
        if let Some(old) = self.entries.remove(&key) {
            self.used_bytes -= old.bytes.len();
        }
        while self.used_bytes + size > self.budget_bytes {
            if !self.evict_one() {
                break;
            }
        }

        self.tick += 1;
        self.used_bytes += size;
        self.entries.insert(
            key,
            CachedPage {
                bytes,
                last_used: self.tick,
            },
        );
    }

    fn evict_one(&mut self) -> bool {
        let Some((&victim, _)) = self.entries.iter().min_by_key(|(_, e)| e.last_used) else {
            return false;
        };
        if let Some(e) = self.entries.remove(&victim) {
            self.used_bytes -= e.bytes.len();
        }
        true
    }

    /// 縮放改變後清掉其他倍率的項目 —— 它們不會再被用到。
    pub fn retain_scale(&mut self, scale: f32) {
        let keep = (scale * 100.0).round() as u32;
        let mut freed = 0;
        self.entries.retain(|k, e| {
            let hit = k.scale_centi == keep;
            if !hit {
                freed += e.bytes.len();
            }
            hit
        });
        self.used_bytes -= freed;
    }

    /// 捲動到某頁時，建議預先渲染哪幾頁。
    ///
    /// 前後都預抓，因為使用者往回捲一樣頻繁。回傳已排除快取中已有的頁。
    pub fn prefetch_targets(
        &self,
        current: u32,
        total: u32,
        radius: u32,
        scale: f32,
    ) -> Vec<RenderKey> {
        let start = current.saturating_sub(radius);
        let end = (current + radius).min(total.saturating_sub(1));
        (start..=end)
            .map(|p| RenderKey::new(p, scale))
            .filter(|k| !self.entries.contains_key(k))
            .collect()
    }

    pub fn clear(&mut self) {
        self.entries.clear();
        self.used_bytes = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn page_bytes(n: usize) -> Vec<u8> {
        vec![0u8; n]
    }

    #[test]
    fn stores_and_retrieves() {
        let mut c = PageCache::new(1000);
        let k = RenderKey::new(0, 1.0);
        assert!(c.get(k).is_none());

        c.put(k, page_bytes(100));
        assert_eq!(c.get(k).unwrap().len(), 100);
        assert_eq!(c.used_bytes(), 100);
    }

    #[test]
    fn evicts_least_recently_used() {
        let mut c = PageCache::new(250);
        for p in 0..2 {
            c.put(RenderKey::new(p, 1.0), page_bytes(100));
        }
        // 讓第 0 頁變成最近使用
        c.get(RenderKey::new(0, 1.0));

        c.put(RenderKey::new(2, 1.0), page_bytes(100));

        assert!(c.get(RenderKey::new(0, 1.0)).is_some(), "最近用過的該留下");
        assert!(
            c.get(RenderKey::new(1, 1.0)).is_none(),
            "最久未用的該被淘汰"
        );
    }

    #[test]
    fn never_exceeds_budget() {
        // 500 頁全部快取會吃掉 4GB —— 預算是硬上限，不是建議值。
        let mut c = PageCache::new(500);
        for p in 0..50 {
            c.put(RenderKey::new(p, 1.0), page_bytes(100));
        }
        assert!(c.used_bytes() <= 500, "實際用了 {}", c.used_bytes());
        assert_eq!(c.len(), 5);
    }

    #[test]
    fn oversized_entry_does_not_wipe_the_cache() {
        // 一次極端縮放不該把所有既有頁面都趕走。
        let mut c = PageCache::new(500);
        c.put(RenderKey::new(0, 1.0), page_bytes(200));
        c.put(RenderKey::new(1, 8.0), page_bytes(9999));

        assert!(c.get(RenderKey::new(0, 1.0)).is_some(), "既有項目該保留");
        assert!(c.get(RenderKey::new(1, 8.0)).is_none(), "過大的項目不放入");
    }

    #[test]
    fn different_scales_are_distinct_entries() {
        let mut c = PageCache::new(10_000);
        c.put(RenderKey::new(0, 1.0), page_bytes(100));
        c.put(RenderKey::new(0, 2.0), page_bytes(400));

        assert_eq!(c.len(), 2);
        assert_eq!(c.get(RenderKey::new(0, 2.0)).unwrap().len(), 400);
    }

    #[test]
    fn replacing_an_entry_does_not_double_count_memory() {
        let mut c = PageCache::new(1000);
        let k = RenderKey::new(0, 1.0);
        c.put(k, page_bytes(100));
        c.put(k, page_bytes(200));

        assert_eq!(c.len(), 1);
        assert_eq!(c.used_bytes(), 200, "重複放入不該累加記憶體");
    }

    #[test]
    fn zoom_change_frees_other_scales() {
        let mut c = PageCache::new(10_000);
        c.put(RenderKey::new(0, 1.0), page_bytes(100));
        c.put(RenderKey::new(1, 1.0), page_bytes(100));
        c.put(RenderKey::new(0, 2.0), page_bytes(400));

        c.retain_scale(2.0);
        assert_eq!(c.len(), 1);
        assert_eq!(c.used_bytes(), 400);
    }

    #[test]
    fn prefetch_looks_both_directions() {
        // 往回捲跟往前捲一樣頻繁。
        let c = PageCache::new(10_000);
        let targets = c.prefetch_targets(10, 500, 2, 1.0);
        let pages: Vec<u32> = targets.iter().map(|k| k.page).collect();
        assert_eq!(pages, vec![8, 9, 10, 11, 12]);
    }

    #[test]
    fn prefetch_clamps_at_document_boundaries() {
        let c = PageCache::new(10_000);
        assert_eq!(
            c.prefetch_targets(0, 3, 2, 1.0)
                .iter()
                .map(|k| k.page)
                .collect::<Vec<_>>(),
            vec![0, 1, 2]
        );
        assert_eq!(
            c.prefetch_targets(2, 3, 2, 1.0)
                .iter()
                .map(|k| k.page)
                .collect::<Vec<_>>(),
            vec![0, 1, 2]
        );
    }

    #[test]
    fn prefetch_skips_already_cached_pages() {
        let mut c = PageCache::new(10_000);
        c.put(RenderKey::new(10, 1.0), page_bytes(100));

        let pages: Vec<u32> = c
            .prefetch_targets(10, 500, 1, 1.0)
            .iter()
            .map(|k| k.page)
            .collect();
        assert_eq!(pages, vec![9, 11], "已快取的不該重複渲染");
    }

    #[test]
    fn hit_rate_tracks_effectiveness() {
        let mut c = PageCache::new(1000);
        c.put(RenderKey::new(0, 1.0), page_bytes(100));

        c.get(RenderKey::new(0, 1.0));
        c.get(RenderKey::new(1, 1.0));

        assert!((c.hit_rate() - 0.5).abs() < 1e-6);
    }

    #[test]
    fn scale_key_roundtrips() {
        assert_eq!(RenderKey::new(0, 2.5).scale(), 2.5);
        assert_eq!(RenderKey::new(0, 1.0), RenderKey::new(0, 1.0));
        assert_ne!(RenderKey::new(0, 1.0), RenderKey::new(0, 1.5));
    }
}
