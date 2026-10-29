//
//  ShaderPaint.metal
//  CalenderPicture
//
//  アニメ調・水彩・切り絵・ドット絵・版画・油絵・ポップアートの塗り方。どれも 1 ピクセルずつ独立に描く。
//  入力はすべて同じ: 0 写真 / 1 少しぼかした写真 / 2 主役のマスク / 3 ぼかした主役のマスク、出力は 4 番。
//
//  線の太さや模様の細かさは、長辺 676px の絵を基準にした「基準ピクセル」で決めている（res = 基準ピクセルでの大きさ）。
//  テクスチャは 0 行目が上なので、uv.y は下に向かって増える。
//

#include <metal_stdlib>
using namespace metal;

/// ShaderPaintFilter.Params と同じ並び
struct ShaderPaintParams {
    /// 出力の大きさ（px）
    float2 size;
    /// 基準ピクセル 1 つが何 px か
    float scale;
};

constexpr sampler linearSampler(coord::normalized, filter::linear, address::clamp_to_edge);

// MARK: - 共通の道具

static float lum(float3 c) { return dot(c, float3(0.299, 0.587, 0.114)); }

static float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float noise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + float2(1, 0)), f.x), mix(hash(i + float2(0, 1)), hash(i + float2(1, 1)), f.x), f.y);
}

static float fbm(float2 p) {
    float s = 0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; }
    return s;
}

/// 彩度を s 倍にする
static float3 saturated(float3 c, float s) { return saturate(mix(float3(lum(c)), c, s)); }

static float3 rgb(texture2d<float> t, float2 uv) { return t.sample(linearSampler, uv).rgb; }
static float gray(texture2d<float> t, float2 uv) { return t.sample(linearSampler, uv).r; }

/// r 基準ピクセルおきに 5×5 点を平均する
static float3 blur(texture2d<float> t, float2 uv, float r, float2 px) {
    float3 s = 0;
    for (int x = -2; x <= 2; x++)
        for (int y = -2; y <= 2; y++) s += rgb(t, uv + float2(x, y) * r * px);
    return s / 25.0;
}

/// ソーベルで測った明るさ（color = true）またはマスクの勾配の大きさ
static float sobel(texture2d<float> t, float2 uv, float r, float2 px, bool color) {
    float v[9];
    for (int i = 0; i < 9; i++) {
        float2 o = float2(i % 3 - 1, i / 3 - 1) * r * px;
        v[i] = color ? lum(rgb(t, uv + o)) : gray(t, uv + o);
    }
    float gx = -v[0] - 2 * v[3] - v[6] + v[2] + 2 * v[5] + v[8];
    float gy = -v[0] - 2 * v[1] - v[2] + v[6] + 2 * v[7] + v[8];
    return length(float2(gx, gy));
}

/// 主役の外に敷く紙の色。どの塗り方でも同じ色にする（CrayonFilter.paperColor と同じ）
constant float3 paperColor = float3(0.98, 0.975, 0.965);

/// 絵の具を乗せる紙の色（細かいムラつき）。主役の中だけで使う
static float3 paper(float2 fp) { return float3(0.972, 0.966, 0.952) * (0.965 + 0.035 * fbm(fp / 6.0)); }

static float bayer2(float2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
static float bayer4(float2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }

// どのカーネルにも共通の引数と前置き
#define PAINT_KERNEL(name) \
kernel void name(texture2d<float, access::sample> photo [[texture(0)]], \
                 texture2d<float, access::sample> soft [[texture(1)]], \
                 texture2d<float, access::sample> mask [[texture(2)]], \
                 texture2d<float, access::sample> softMask [[texture(3)]], \
                 texture2d<float, access::write> output [[texture(4)]], \
                 constant ShaderPaintParams &params [[buffer(0)]], \
                 uint2 gid [[thread_position_in_grid]])

#define PAINT_BEGIN \
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return; \
    float2 uv = (float2(gid) + 0.5) / params.size; \
    float2 res = params.size / params.scale; \
    float2 px = 1.0 / res; \
    float2 fp = uv * res;

#define PAINT_END(color) output.write(float4(saturate(color), 1.0), gid);

// MARK: - アニメ調

/// 明るさを 3 段に分けて塗り、輪郭線を引く
PAINT_KERNEL(paintCel) {
    PAINT_BEGIN
    float3 c = rgb(soft, uv);
    float l = lum(c);
    float3 chroma = c / max(l, 0.001);
    float level = mix(0.3, 0.62, smoothstep(0.28, 0.32, l));
    level = mix(level, 0.9, smoothstep(0.62, 0.66, l));
    float3 color = saturated(saturate(chroma * level), 1.3);

    float m = smoothstep(0.4, 0.6, gray(mask, uv));
    float edge = smoothstep(0.22, 0.42, sobel(soft, uv, 1.2, px, true)) * m;
    float outline = smoothstep(0.15, 0.4, sobel(mask, uv, 2, px, false));
    color = mix(paperColor, color, m);
    color = mix(color, float3(0.14, 0.11, 0.16), max(edge, outline));
    PAINT_END(color)
}

// MARK: - 水彩

/// にじんだ境界、縁に溜まる絵の具、紙の粒
PAINT_KERNEL(paintWatercolor) {
    PAINT_BEGIN
    float2 wobble = (float2(fbm(uv * 5), fbm(uv * 5 + 9.1)) - 0.5) * 18 * px;
    float3 c = rgb(soft, uv + wobble);
    float3 wide = blur(soft, uv + wobble, 6, px);
    c = mix(c, floor(c * 5 + 0.5) / 5, 0.35);
    // 色の変わり目に絵の具が溜まって濃くなる
    float pooling = saturate(length(c - wide) * 2.2);
    c = mix(c, c * c * 0.9, pooling * 0.8);
    c = saturated(c, 1.25);
    c = mix(c, float3(1), 0.12);
    c *= 0.9 + 0.2 * noise(fp / 2.5);

    float m = smoothstep(0.35, 0.65, gray(softMask, uv + wobble * 1.8) + (fbm(uv * 14) - 0.5) * 0.45);
    float rim = smoothstep(0.0, 0.25, m) * (1 - smoothstep(0.25, 0.6, m));
    float3 color = mix(paperColor, c * paper(fp) * (1 - rim * 0.14), m);
    PAINT_END(color)
}

// MARK: - 切り絵

/// 何枚目の色紙か（0 = 台紙、1〜3 = 主役を明るさで分けた層）
static float paperLayer(texture2d<float> soft, texture2d<float> softMask, float2 q, float2 px) {
    if (gray(softMask, q) < 0.5) return 0;
    return 1 + floor(clamp(lum(blur(soft, q, 4, px)), 0.0, 0.999) * 3);
}

/// 明るさで色紙を 3 層に切り分けて重ね、上の層が下の層（と下の紙）に影を落とす
PAINT_KERNEL(paintPaperCut) {
    PAINT_BEGIN
    // 紙をはさみで切ったような、少しガタつく切り口
    float2 q = uv + (float2(noise(uv * 30), noise(uv * 30 + 5)) - 0.5) * 4 * px;
    float layer = paperLayer(soft, softMask, q, px);
    // 光は左上から。左上の層のほうが高ければ、ここはその影
    float above = paperLayer(soft, softMask, q + float2(-5, -6) * px, px);

    float3 color;
    if (layer < 0.5) {
        color = paperColor;
    } else {
        color = saturated(floor(blur(soft, q, 5, px) * 3 + 0.5) / 3, 1.2);
        color = mix(color, float3(1), 0.1) * (0.78 + 0.1 * layer);
        // 色紙の繊維
        color *= 0.95 + 0.05 * fbm(fp / 3);
    }
    if (above > layer) color *= layer < 0.5 ? 0.8 : 0.62;
    PAINT_END(color)
}

// MARK: - ドット絵

/// 大きな画素に縮め、ディザで減色する。主役にはドットのフチ取りをつける
PAINT_KERNEL(paintPixelArt) {
    PAINT_BEGIN
    const float cell = 8;
    float2 p = floor(fp / cell);
    float2 center = (p + 0.5) * cell * px;
    float3 c = saturated(rgb(photo, center), 1.25);
    // 4 段に減色し、段の境目だけ少しディザで混ぜる（強くかけると平らな面まで市松模様になる）
    c = saturate(floor(c * 4 + 0.5 + (bayer4(p) - 0.5) * 0.7) / 4);

    float2 spacing = cell * px;
    bool inside = gray(mask, center) > 0.5;
    int neighbors = 0;
    const float2 sides[4] = { float2(1, 0), float2(-1, 0), float2(0, 1), float2(0, -1) };
    for (int i = 0; i < 4; i++) neighbors += gray(mask, center + sides[i] * spacing) > 0.5 ? 1 : 0;
    float3 color = paperColor;
    if (inside) {
        // 画素の境目をうっすら見せる
        float2 f = fract(fp / cell);
        color = c * (0.94 + 0.06 * step(0.12, min(f.x, f.y)));
        if (neighbors < 4) color = float3(0.12, 0.1, 0.18);
    }
    PAINT_END(color)
}

// MARK: - 版画

constant float3 woodblockInks[8] = {
    float3(0.13, 0.2, 0.36),   // 藍
    float3(0.82, 0.3, 0.2),    // 朱
    float3(0.85, 0.65, 0.3),   // 黄土
    float3(0.5, 0.6, 0.45),    // 若竹
    float3(0.95, 0.9, 0.78),   // 生成り
    float3(0.9, 0.66, 0.6),    // 薄紅
    float3(0.16, 0.14, 0.13),  // 墨
    float3(0.55, 0.72, 0.82),  // 水色
};

/// 主役を決まった色のインクだけで刷り、輪郭・木目を入れる
PAINT_KERNEL(paintWoodblock) {
    PAINT_BEGIN
    float3 c = saturated(rgb(soft, uv), 1.3);
    float3 ink = woodblockInks[0];
    float best = INFINITY;
    for (int i = 0; i < 8; i++) {
        float3 d = c - woodblockInks[i];
        if (dot(d, d) < best) { best = dot(d, d); ink = woodblockInks[i]; }
    }
    float m = smoothstep(0.4, 0.6, gray(mask, uv));
    float grain = noise(float2(uv.x * 14, uv.y * 260) + noise(uv * 8) * 3);
    ink *= (0.93 + 0.07 * grain) * (0.96 + 0.04 * fbm(fp / 4));
    float3 color = mix(paperColor, ink, m);
    float edge = smoothstep(0.2, 0.4, sobel(soft, uv, 1.6, px, true)) * m;
    float outline = smoothstep(0.12, 0.35, sobel(mask, uv, 2.5, px, false));
    color = mix(color, float3(0.12, 0.12, 0.16), max(edge, outline) * 0.9);
    PAINT_END(color)
}

// MARK: - 油絵

/// o の向きの 5×5 の範囲の平均色と、色のばらつき
static float kuwaharaRegion(texture2d<float> photo, float2 uv, float2 o, float2 px, thread float3 &mean) {
    float3 sum = 0, squares = 0;
    for (int x = 0; x < 5; x++)
        for (int y = 0; y < 5; y++) {
            float3 c = rgb(photo, uv + float2(x, y) * o * 1.5 * px);
            sum += c;
            squares += c * c;
        }
    mean = sum / 25;
    float3 variance = squares / 25 - mean * mean;
    return variance.r + variance.g + variance.b;
}

/// Kuwahara フィルタ: 周りの 4 方向のうち、いちばん色がそろっている方向の平均色で塗る（筆のタッチ状になる）。
/// 主役だけを塗り、主役の外は紙のまま残す
PAINT_KERNEL(paintOil) {
    PAINT_BEGIN
    float3 color = 0;
    float best = INFINITY;
    const float2 directions[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    for (int i = 0; i < 4; i++) {
        float3 mean;
        float variance = kuwaharaRegion(photo, uv, directions[i], px, mean);
        if (variance < best) { best = variance; color = mean; }
    }
    color = saturated(color, 1.18);
    // 主役の縁は、筆でかすれたように横向きのムラで途切れさせる
    float stroke = noise(fp * float2(0.08, 0.5));
    float m = smoothstep(0.35, 0.65, gray(softMask, uv) + (stroke - 0.5) * 0.35);
    // キャンバスの布目
    color *= 0.95 + 0.05 * (sin(fp.x * 1.6) * sin(fp.y * 1.6) * 0.5 + 0.5);
    color *= 0.96 + 0.06 * stroke;
    color = mix(paperColor, color, m);
    PAINT_END(color)
}

// MARK: - ポップアート

/// 角度 angle の網点で、量 amount のインクが乗っているか（0〜1）
static float halftoneDot(float2 fp, float angle, float amount) {
    float2x2 rotation = float2x2(float2(cos(angle), -sin(angle)), float2(sin(angle), cos(angle)));
    float2 f = fract(rotation * fp / 7) - 0.5;
    float radius = sqrt(saturate(amount)) * 0.62;
    return 1 - smoothstep(radius - 0.08, radius + 0.08, length(f));
}

/// CMY の網点で刷ったアメコミ風。主役には太い輪郭
PAINT_KERNEL(paintPopArt) {
    PAINT_BEGIN
    float3 ink = 1 - saturated(rgb(soft, uv), 1.3);
    float3 color = 1;
    color *= mix(float3(1), float3(0, 0.68, 0.94), halftoneDot(fp, 0.26, ink.r));
    color *= mix(float3(1), float3(0.93, 0, 0.55), halftoneDot(fp, 1.31, ink.g));
    color *= mix(float3(1), float3(1, 0.92, 0), halftoneDot(fp, 0, ink.b));

    float m = smoothstep(0.4, 0.6, gray(mask, uv));
    float edge = smoothstep(0.25, 0.45, sobel(soft, uv, 1.5, px, true)) * m;
    float outline = smoothstep(0.12, 0.35, sobel(mask, uv, 3.5, px, false));
    color = mix(paperColor, color, m);
    color = mix(color, float3(0.07, 0.06, 0.1), max(edge, outline));
    PAINT_END(color)
}
