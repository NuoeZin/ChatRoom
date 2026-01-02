/// @function draw_simple_rounded_rect(x1, y1, x2, y2, radius, filled)
/// @description 绘制简化的圆角矩形（性能优化版）

function draw_simple_rounded_rect(x1, y1, x2, y2, radius, filled) {
    // 性能优化：使用简单的圆角近似
    if (radius <= 0) {
        // 如果半径为0或负数，直接绘制矩形
        draw_rectangle(x1, y1, x2, y2, filled);
        return;
    }
    
    // 限制圆角半径不超过矩形尺寸的一半
    var max_radius = min((x2 - x1) / 2, (y2 - y1) / 2);
    radius = min(radius, max_radius);
    
    if (radius <= 2) {
        // 小半径时，直接绘制矩形（性能更好）
        draw_rectangle(x1, y1, x2, y2, filled);
    } else {
        // 中等半径时，使用标准圆角矩形
        draw_roundrect_ext(x1, y1, x2, y2, radius, radius, filled);
    }
}