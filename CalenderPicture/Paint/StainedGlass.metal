//
//  StainedGlass.metal
//  CalenderPicture
//
//  主役をボロノイのガラス片に分け、鉛の枠でつないだステンドグラスにする。
//  ガラス片の位置は乱数で揺らした格子から毎ピクセル計算するので、点のデータは渡さない。
//

#include <metal_stdlib>
using namespace metal;

/// StainedGlassFilter.Params と同じ並び
struct StainedGlassParams {
    /// ガラス片 1 枚のおおよその大きさ（px）
    float cellSize;
    /// 鉛の枠の太さ（px）
    float leadWidth;
    /// 主役の輪郭を囲む鉛の枠の太さ（px）
    float outlineWidth;
};

/// 格子のマス目ごとに決まる 0〜1 の乱数 2 つ
static float2 hash2(int2 cell) {
    uint h = uint(cell.x) * 73856093u ^ uint(cell.y) * 19349663u;
    h = (h ^ (h >> 16)) * 0x45d9f3bu;
    h = (h ^ (h >> 16)) * 0x45d9f3bu;
    h ^= h >> 16;
    return float2(h & 0xffffu, h >> 16) / 65535.0;
}

/// 滑らかな値ノイズ（0〜1）。ガラスのムラに使う
static float valueNoise(float2 p) {
    int2 i = int2(floor(p));
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash2(i).x, b = hash2(i + int2(1, 0)).x;
    float c = hash2(i + int2(0, 1)).x, d = hash2(i + int2(1, 1)).x;
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/// マス目 cell のガラス片の中心（マス目単位、マス目の中で少し内側に寄せて片の大きさを揃える）
static float2 site(int2 cell) {
    return float2(cell) + 0.15 + 0.7 * hash2(cell);
}

/// ガラス片の中心が主役の中にあれば、その片は主役の一部
static bool isSubject(int2 cell, texture2d<float, access::sample> mask, sampler s, float cellSize) {
    return mask.sample(s, site(cell) * cellSize).r > 0.5;
}

/// color: 減色済みの色、mask: 主役のマスク（主役 = 1）、output: 乗算済みアルファの絵（主役の外は透明）
kernel void stainedGlass(texture2d<float, access::sample> color [[texture(0)]],
                         texture2d<float, access::sample> mask [[texture(1)]],
                         texture2d<float, access::write> output [[texture(2)]],
                         constant StainedGlassParams &params [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    constexpr sampler pixelSampler(coord::pixel, filter::linear, address::clamp_to_edge);

    float2 pixel = float2(gid) + 0.5;
    float2 p = pixel / params.cellSize;
    int2 base = int2(floor(p));

    // 1. 一番近いガラス片を探す
    int2 nearest = base;
    float2 toNearest = float2(0);
    float best = INFINITY;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            int2 cell = base + int2(x, y);
            float2 r = site(cell) - p;
            float d = dot(r, r);
            if (d < best) { best = d; nearest = cell; toNearest = r; }
        }
    }
    bool inside = isSubject(nearest, mask, pixelSampler, params.cellSize);

    // 2. 隣のガラス片との境界までの距離（マス目単位）。主役の外側の片との境界は別に測る
    float toEdge = INFINITY, toOutline = INFINITY;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            int2 cell = nearest + int2(x, y);
            if (all(cell == nearest)) continue;
            float2 r = site(cell) - p;
            float2 between = r - toNearest;
            if (dot(between, between) < 1e-6) continue;
            float d = dot(0.5 * (toNearest + r), normalize(between));
            if (isSubject(cell, mask, pixelSampler, params.cellSize) == inside) {
                toEdge = min(toEdge, d);
            } else {
                toOutline = min(toOutline, d);
            }
        }
    }
    float edge = toEdge * params.cellSize;
    float outline = toOutline * params.cellSize;

    // 3. 鉛の枠。主役の輪郭は外側の片にもはみ出させ、太い縁取りにする
    float leadHalf = params.leadWidth * 0.5;
    float outlineHalf = params.outlineWidth * 0.5;
    float leadDistance;  // 枠の中心線からの距離の割合（0 = 中心、1 = 縁）
    float leadCoverage;
    if (inside) {
        float lead = 1.0 - smoothstep(leadHalf - 0.75, leadHalf + 0.75, edge);
        float rim = 1.0 - smoothstep(outlineHalf - 0.75, outlineHalf + 0.75, outline);
        leadCoverage = max(lead, rim);
        leadDistance = min(edge / leadHalf, outline / outlineHalf);
    } else {
        leadCoverage = 1.0 - smoothstep(outlineHalf - 0.75, outlineHalf + 0.75, outline);
        leadDistance = outline / outlineHalf;
    }
    // 枠は真ん中が少し光る丸い棒に見せる
    float3 leadColor = mix(float3(0.36, 0.35, 0.37), float3(0.11, 0.105, 0.12), saturate(leadDistance));

    // 4. ガラス。片ごとに中心の色 1 色で塗り、光が透ける明るさのムラと、枠際の影をつける
    float3 glass = color.sample(pixelSampler, site(nearest) * params.cellSize).rgb;
    float2 id = float2(nearest);
    float mottle = valueNoise(pixel / (params.cellSize * 0.22) + id * 17.0);
    float glow = 1.0 - saturate(length(toNearest) * 1.1);
    float shade = 0.82 + 0.14 * glow + 0.12 * mottle + 0.08 * (hash2(nearest).y - 0.5);
    shade *= mix(0.78, 1.0, smoothstep(leadHalf, leadHalf + params.cellSize * 0.12, edge));
    glass = saturate(glass * shade);
    // 片の真ん中寄りに、斜めの淡い光の反射を入れる
    float sheen = smoothstep(0.75, 1.0, sin((pixel.x + pixel.y) / params.cellSize * 2.1 + id.x * 1.7) * 0.5 + 0.5);
    glass = mix(glass, float3(1.0), sheen * 0.12 * glow);

    // 書き出しは乗算済みアルファ（主役の外は、はみ出した縁取りの分だけ不透明）
    float4 result = inside
        ? float4(mix(glass, leadColor, leadCoverage), 1.0)
        : float4(leadColor * leadCoverage, leadCoverage);
    output.write(result, gid);
}
