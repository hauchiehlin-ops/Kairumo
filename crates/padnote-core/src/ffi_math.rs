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
        ("×", "*"),
        ("✕", "*"),
        ("·", "*"),
        ("÷", "/"),
        ("∕", "/"),
        ("—", "-"),
        ("–", "-"),
        ("−", "-"),
        ("（", "("),
        ("）", ")"),
        ("，", ","),
        ("　", " "),
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
    let mut parser = Parser {
        chars: &chars,
        pos: 0,
    };
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
        let mut value = self.primary()?;
        loop {
            if self.eat('%') {
                value /= 100.0;
            } else if self.eat('!') {
                value = factorial(value)?;
            } else {
                break;
            }
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
            .is_some_and(|c| c.is_alphanumeric() || *c == '_' || *c == 'π' || *c == 'φ' || *c == 'ϕ')
        {
            self.pos += 1;
        }
        if self.pos == start {
            return None;
        }
        let name: String = self.chars[start..self.pos]
            .iter()
            .collect::<String>()
            .to_lowercase();

        // 常用科學常數
        match name.as_str() {
            "π" | "pi" => return Some(PI),
            "e" => return Some(std::f64::consts::E),
            "φ" | "phi" => return Some(1.618033988749895), // 黃金比例
            "c" => return Some(299_792_458.0),             // 光速 m/s
            "g" => return Some(9.80665),                   // 標準重力加速度 m/s²
            "h" => return Some(6.62607015e-34),            // 普朗克常數 J·s
            "k" | "kb" => return Some(1.380649e-23),       // 波茲曼常數 J/K
            "na" => return Some(6.02214076e23),            // 亞佛加厥常數 mol⁻¹
            _ => {}
        }

        // 函式一定要接括號。`sqrt 4` 看不懂就回錯誤，不要猜。
        if !self.eat('(') {
            return None;
        }
        // 引數串列支援多個引數（以逗號區隔）
        let mut args: Vec<f64> = Vec::new();
        if !self.eat(')') {
            loop {
                let arg = self.expression()?;
                args.push(arg);
                if self.eat(',') {
                    continue;
                } else if self.eat(')') {
                    break;
                } else {
                    return None;
                }
            }
        }

        Some(match (name.as_str(), args.as_slice()) {
            ("sqrt", [x]) => x.sqrt(),
            ("cbrt", [x]) => x.cbrt(),
            ("abs", [x]) => x.abs(),
            ("sin", [x]) => x.sin(),
            ("cos", [x]) => x.cos(),
            ("tan", [x]) => x.tan(),
            ("asin", [x]) => x.asin(),
            ("acos", [x]) => x.acos(),
            ("atan", [x]) => x.atan(),
            ("atan2", [y, x]) => y.atan2(*x),
            ("sinh", [x]) => x.sinh(),
            ("cosh", [x]) => x.cosh(),
            ("tanh", [x]) => x.tanh(),
            ("asinh", [x]) => x.asinh(),
            ("acosh", [x]) => x.acosh(),
            ("atanh", [x]) => x.atanh(),
            ("ln", [x]) => x.ln(),
            ("log", [x]) => x.log10(),
            ("log10", [x]) => x.log10(),
            ("log2", [x]) => x.log2(),
            ("exp", [x]) => x.exp(),
            ("deg", [x]) => x.to_degrees(),
            ("rad", [x]) => x.to_radians(),
            ("round", [x]) => x.round(),
            ("floor", [x]) => x.floor(),
            ("ceil", [x]) => x.ceil(),
            ("fact", [x]) => factorial(*x)?,
            ("gamma", [x]) => gamma_approx(*x)?,
            ("pow", [b, e]) => b.powf(*e),
            ("gcd", [a, b]) => gcd_float(*a, *b)?,
            ("lcm", [a, b]) => lcm_float(*a, *b)?,
            ("ncr", [n, r]) => ncr(*n, *r)?,
            ("npr", [n, r]) => npr(*n, *r)?,
            ("min", [a, b]) => a.min(*b),
            ("max", [a, b]) => a.max(*b),
            _ => return None,
        })
    }
}

/// 階乘（支援 0 到 170 的整數）。
fn factorial(n: f64) -> Option<f64> {
    if n < 0.0 || (n - n.round()).abs() > 1e-9 {
        return None;
    }
    let n = n.round() as u64;
    if n > 170 {
        return None; // 超過 f64 最大值
    }
    let mut acc = 1.0f64;
    for i in 2..=n {
        acc *= i as f64;
    }
    Some(acc)
}

/// 組合數 nCr = n! / (r! * (n-r)!)
fn ncr(n: f64, r: f64) -> Option<f64> {
    if n < 0.0 || r < 0.0 || r > n || (n - n.round()).abs() > 1e-9 || (r - r.round()).abs() > 1e-9 {
        return None;
    }
    let n = n.round() as u64;
    let mut r = r.round() as u64;
    if r > n {
        return None;
    }
    if r > n - r {
        r = n - r;
    }
    let mut ans = 1.0f64;
    for i in 1..=r {
        ans = ans * (n - r + i) as f64 / i as f64;
    }
    Some(ans.round())
}

/// 排列數 nPr = n! / (n-r)!
fn npr(n: f64, r: f64) -> Option<f64> {
    if n < 0.0 || r < 0.0 || r > n || (n - n.round()).abs() > 1e-9 || (r - r.round()).abs() > 1e-9 {
        return None;
    }
    let n = n.round() as u64;
    let r = r.round() as u64;
    let mut ans = 1.0f64;
    for i in (n - r + 1)..=n {
        ans *= i as f64;
    }
    Some(ans)
}

/// 最大公因數
fn gcd_float(a: f64, b: f64) -> Option<f64> {
    if (a - a.round()).abs() > 1e-9 || (b - b.round()).abs() > 1e-9 {
        return None;
    }
    let mut u = a.round().abs() as u64;
    let mut v = b.round().abs() as u64;
    while v != 0 {
        let r = u % v;
        u = v;
        v = r;
    }
    Some(u as f64)
}

/// 最小公倍數
fn lcm_float(a: f64, b: f64) -> Option<f64> {
    if (a - a.round()).abs() > 1e-9 || (b - b.round()).abs() > 1e-9 {
        return None;
    }
    let g = gcd_float(a, b)?;
    if g == 0.0 {
        return Some(0.0);
    }
    let u = a.round().abs();
    let v = b.round().abs();
    Some((u / g) * v)
}

/// Lanczos 近似 Gamma 函數 (近似微積分與工數階乘拓展)
fn gamma_approx(z: f64) -> Option<f64> {
    if z <= 0.0 && (z - z.round()).abs() < 1e-9 {
        return None; // 非正整數有極點 (pole)
    }
    // Lanczos 係數 g=7, n=9
    let p = [
        0.99999999999980993,
        676.5203681218851,
        -1259.1392167224028,
        771.32342877765313,
        -176.61502916214059,
        12.507343278686905,
        -0.13857109526572012,
        9.9843695780195716e-6,
        1.5056327351493116e-7,
    ];
    let z = if z < 0.5 {
        // 反射公式: Γ(1-z) Γ(z) = π / sin(π z)
        let sin_pi_z = (PI * z).sin();
        if sin_pi_z.abs() < 1e-15 {
            return None;
        }
        return Some(PI / (sin_pi_z * gamma_approx(1.0 - z)?));
    } else {
        z - 1.0
    };
    let mut x = p[0];
    for (i, &val) in p.iter().enumerate().skip(1) {
        x += val / (z + i as f64);
    }
    let t = z + 7.5;
    let sqrt_two_pi = 2.5066282746310005;
    Some(sqrt_two_pi * t.powf(z + 0.5) * (-t).exp() * x)
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

    #[test]
    fn engineering_and_scientific_calculations() {
        // 階乘與後綴
        assert_eq!(value("5!"), 120.0);
        assert_eq!(value("0!"), 1.0);
        assert_eq!(value("fact(6)"), 720.0);

        // 多引數函數
        assert_eq!(value("ncr(5, 2)"), 10.0);
        assert_eq!(value("npr(5, 2)"), 20.0);
        assert_eq!(value("gcd(24, 36)"), 12.0);
        assert_eq!(value("lcm(4, 6)"), 12.0);
        assert_eq!(value("pow(2, 8)"), 256.0);
        assert_eq!(value("min(15, 7)"), 7.0);
        assert_eq!(value("max(15, 7)"), 15.0);

        // 三角與反三角、雙曲函數
        assert_eq!(value("deg(pi)"), 180.0);
        assert_eq!(value("rad(180)"), PI);
        assert!((value("sin(pi/2)") - 1.0).abs() < 1e-9);
        assert!((value("cos(0)") - 1.0).abs() < 1e-9);
        assert!((value("tan(pi/4)") - 1.0).abs() < 1e-9);
        assert!((value("asin(1)") - PI / 2.0).abs() < 1e-9);
        assert!((value("atan(1)") - PI / 4.0).abs() < 1e-9);
        assert!((value("sinh(0)")).abs() < 1e-9);
        assert!((value("cosh(0)") - 1.0).abs() < 1e-9);

        // 指數與對數
        assert_eq!(value("exp(0)"), 1.0);
        assert_eq!(value("log10(1000)"), 3.0);
        assert_eq!(value("log2(16)"), 4.0);
        assert_eq!(value("cbrt(27)"), 3.0);

        // 常數
        assert_eq!(value("c"), 299_792_458.0);
        assert_eq!(value("g"), 9.80665);
        assert!((value("phi") - 1.618033988749895).abs() < 1e-9);

        // 伽瑪函數 Γ(5) = 4! = 24
        assert!((value("gamma(5)") - 24.0).abs() < 1e-6);
    }
}
