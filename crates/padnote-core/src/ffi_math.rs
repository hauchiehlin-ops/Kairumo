//! 算式求值。
//!
//! # 為什麼在核心
//!
//! Apple 端原本走 `NSExpression` —— 那是 Foundation 專屬的，Android 沒有對應品。
//! 兩邊各寫一份的結果是同一條算式可能算出不同答案，或一邊算得出、一邊算不出，
//! 而使用者是把它當計算機在用的。
//!
//! 順帶擺脫 `NSExpression`：它對錯誤輸入會**丟出 Objective-C 例外**，Swift 攔不到，
//! 直接讓 App 當掉。自己剖析就沒有這個問題 —— 看不懂就回錯誤。

use std::f64::consts::PI;

/// 求值結果。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiMathResult {
    /// 算得出來時為 true。
    pub ok: bool,
    /// 正規化之後的算式（全形換半形、π 換成數值…）。
    pub normalized: String,
    /// 數值。`ok` 為 false 時沒有意義。
    pub value: f64,
    /// 給人看的結果字串（整數不補小數點，小數最多六位）。
    pub formatted: String,
    /// 算不出來的原因（語系鍵）。`ok` 為 true 時是空字串。
    pub error_key: String,
}

/// 把使用者輸入正規化成標準算式。
///
/// 手寫辨識與中文輸入法會給出全形符號與 `×` `÷`，不換的話全部算不出來。
fn normalize(raw: &str) -> String {
    let mut s = raw.trim().to_string();
    // 結尾的等號是使用者寫算式的習慣，不是運算子。
    if s.ends_with('=') {
        s.pop();
    }
    // 全形數字與小數點。中文輸入法在全形模式下打出來的就是這些 ——
    // 只換運算子不換數字的話，「６÷２」仍然算不出來（測試抓到過）。
    s = s
        .chars()
        .map(|c| match c {
            '０'..='９' => char::from(b'0' + (c as u32 - '０' as u32) as u8),
            '．' => '.',
            other => other,
        })
        .collect();

    for (from, to) in [
        ("×", "*"), ("✕", "*"), ("·", "*"),
        ("÷", "/"), ("∕", "/"),
        ("—", "-"), ("–", "-"), ("−", "-"),
        ("（", "("), ("）", ")"),
        ("，", ","), ("　", " "),
    ] {
        s = s.replace(from, to);
    }
    s
}

/// 求值。看不懂就回錯誤，不會 panic。
#[uniffi::export]
pub fn math_evaluate(expression: String) -> FfiMathResult {
    let normalized = normalize(&expression);
    if normalized.trim().is_empty() {
        return FfiMathResult {
            ok: false,
            normalized,
            value: 0.0,
            formatted: String::new(),
            error_key: "math_error_empty".into(),
        };
    }

    let chars: Vec<char> = normalized.chars().collect();
    let mut parser = Parser { chars: &chars, pos: 0 };
    let value = match parser.expression() {
        Some(v) => v,
        None => return failure(normalized, "math_error_bad_expression"),
    };
    parser.skip_spaces();
    // 沒吃完代表後面有看不懂的東西 —— 「1+2abc」不該悄悄算成 3。
    if parser.pos < chars.len() {
        return failure(normalized, "math_error_bad_expression");
    }
    if !value.is_finite() {
        return failure(normalized, "math_error_not_finite");
    }

    FfiMathResult {
        ok: true,
        normalized,
        value,
        formatted: format_number(value),
        error_key: String::new(),
    }
}

fn failure(normalized: String, key: &str) -> FfiMathResult {
    FfiMathResult {
        ok: false,
        normalized,
        value: 0.0,
        formatted: String::new(),
        error_key: key.into(),
    }
}

/// 整數不補小數點，小數最多六位且不留尾隨的零。
///
/// `0.1 + 0.2` 在浮點數裡是 0.30000000000000004 —— 原樣顯示會讓使用者以為
/// 計算機壞了。六位是「看得出精度又不暴露浮點誤差」的折衷。
fn format_number(value: f64) -> String {
    if (value - value.round()).abs() < 1e-9 && value.abs() < 1e15 {
        return format!("{}", value.round() as i64);
    }
    let mut s = format!("{value:.6}");
    while s.ends_with('0') {
        s.pop();
    }
    if s.ends_with('.') {
        s.pop();
    }
    s
}

/// 遞迴下降剖析器。
///
/// 文法（由低到高優先）：
/// ```text
/// expression := term (('+' | '-') term)*
/// term       := power (('*' | '/' | '%') power)*
/// power      := unary ('^' power)?          // 右結合
/// unary      := ('+' | '-')? postfix
/// postfix    := primary '%'?                // 百分比：50% → 0.5
/// primary    := number | constant | function '(' expression ')' | '(' expression ')'
/// ```
struct Parser<'a> {
    chars: &'a [char],
    pos: usize,
}

impl<'a> Parser<'a> {
    fn skip_spaces(&mut self) {
        while self.pos < self.chars.len() && self.chars[self.pos].is_whitespace() {
            self.pos += 1;
        }
    }

    fn peek(&mut self) -> Option<char> {
        self.skip_spaces();
        self.chars.get(self.pos).copied()
    }

    fn eat(&mut self, c: char) -> bool {
        if self.peek() == Some(c) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    fn expression(&mut self) -> Option<f64> {
        let mut value = self.term()?;
        loop {
            if self.eat('+') {
                value += self.term()?;
            } else if self.eat('-') {
                value -= self.term()?;
            } else {
                return Some(value);
            }
        }
    }

    fn term(&mut self) -> Option<f64> {
        let mut value = self.power()?;
        loop {
            if self.eat('*') {
                value *= self.power()?;
            } else if self.eat('/') {
                let rhs = self.power()?;
                // 除以零不是 panic，是「算不出來」。回 inf 讓上層判定。
                value /= rhs;
            } else {
                return Some(value);
            }
        }
    }

    fn power(&mut self) -> Option<f64> {
        let base = self.unary()?;
        if self.eat('^') {
            // 右結合：2^3^2 是 2^(3^2)。
            let exponent = self.power()?;
            return Some(base.powf(exponent));
        }
        Some(base)
    }

    fn unary(&mut self) -> Option<f64> {
        if self.eat('-') {
            return Some(-self.unary()?);
        }
        if self.eat('+') {
            return self.unary();
        }
        self.postfix()
    }

    fn postfix(&mut self) -> Option<f64> {
        let value = self.primary()?;
        // 百分比是後綴：50% = 0.5。寫成 100*50% 時使用者要的是 50。
        if self.eat('%') {
            return Some(value / 100.0);
        }
        Some(value)
    }

    fn primary(&mut self) -> Option<f64> {
        self.skip_spaces();
        if self.eat('(') {
            let value = self.expression()?;
            if !self.eat(')') {
                return None;
            }
            return Some(value);
        }

        let start = self.pos;
        // 數字
        if self
            .chars
            .get(self.pos)
            .is_some_and(|c| c.is_ascii_digit() || *c == '.')
        {
            while self
                .chars
                .get(self.pos)
                .is_some_and(|c| c.is_ascii_digit() || *c == '.')
            {
                self.pos += 1;
            }
            let text: String = self.chars[start..self.pos].iter().collect();
            return text.parse::<f64>().ok();
        }

        // 識別字：常數或函式
        while self
            .chars
            .get(self.pos)
            .is_some_and(|c| c.is_alphabetic() || *c == 'π')
        {
            self.pos += 1;
        }
        if self.pos == start {
            return None;
        }
        let name: String = self.chars[start..self.pos].iter().collect::<String>().to_lowercase();

        match name.as_str() {
            "π" | "pi" => return Some(PI),
            "e" => return Some(std::f64::consts::E),
            _ => {}
        }

        // 函式一定要接括號。`sqrt 4` 看不懂就回錯誤，不要猜。
        if !self.eat('(') {
            return None;
        }
        let arg = self.expression()?;
        if !self.eat(')') {
            return None;
        }
        Some(match name.as_str() {
            "sqrt" => arg.sqrt(),
            "abs" => arg.abs(),
            "sin" => arg.sin(),
            "cos" => arg.cos(),
            "tan" => arg.tan(),
            "ln" => arg.ln(),
            "log" => arg.log10(),
            "round" => arg.round(),
            "floor" => arg.floor(),
            "ceil" => arg.ceil(),
            _ => return None,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn value(expr: &str) -> f64 {
        let r = math_evaluate(expr.into());
        assert!(r.ok, "{expr} 應該算得出來，實得錯誤 {}", r.error_key);
        r.value
    }

    fn fails(expr: &str) {
        assert!(!math_evaluate(expr.into()).ok, "{expr} 不該算得出來");
    }

    #[test]
    fn basic_arithmetic() {
        assert_eq!(value("1+2"), 3.0);
        assert_eq!(value("10-4"), 6.0);
        assert_eq!(value("6*7"), 42.0);
        assert_eq!(value("9/3"), 3.0);
    }

    #[test]
    fn precedence_and_parentheses() {
        assert_eq!(value("2+3*4"), 14.0);
        assert_eq!(value("(2+3)*4"), 20.0);
        assert_eq!(value("2^3^2"), 512.0, "次方要右結合");
    }

    #[test]
    fn full_width_and_cjk_symbols() {
        // 手寫辨識與中文輸入法給的就是這些符號。不換的話全部算不出來。
        assert_eq!(value("６÷２"), 3.0);
        assert_eq!(value("2×3"), 6.0);
        assert_eq!(value("（1+2）*3"), 9.0);
    }

    #[test]
    fn trailing_equals_is_not_an_operator() {
        assert_eq!(value("1+2="), 3.0);
    }

    #[test]
    fn percent_is_a_suffix() {
        assert_eq!(value("50%"), 0.5);
        assert_eq!(value("200*10%"), 20.0);
    }

    #[test]
    fn constants_and_functions() {
        assert!((value("pi") - PI).abs() < 1e-9);
        assert!((value("π") - PI).abs() < 1e-9);
        assert_eq!(value("sqrt(16)"), 4.0);
        assert_eq!(value("abs(0-5)"), 5.0);
        assert_eq!(value("round(2.6)"), 3.0);
    }

    #[test]
    fn trailing_garbage_is_rejected() {
        // 「1+2abc」悄悄算成 3 的話，使用者不會發現自己打錯了。
        fails("1+2abc");
        fails("((1+2)");
        fails("sqrt 4");
        fails("");
        fails("+");
    }

    #[test]
    fn division_by_zero_is_an_error_not_a_crash() {
        fails("1/0");
    }

    #[test]
    fn formatting_hides_floating_point_noise() {
        // 0.1+0.2 在浮點數裡是 0.30000000000000004。
        let r = math_evaluate("0.1+0.2".into());
        assert_eq!(r.formatted, "0.3");
        // 整數不要補小數點。
        assert_eq!(math_evaluate("4/2".into()).formatted, "2");
    }

    #[test]
    fn unary_minus() {
        assert_eq!(value("-5+3"), -2.0);
        assert_eq!(value("-(2+3)"), -5.0);
    }
}
