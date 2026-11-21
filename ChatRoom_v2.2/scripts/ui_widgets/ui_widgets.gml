/// @function add_font_r(file, size, bold, last_code)
/// @description 从 resources 目录加载字体，兼容 IDE / 导出后的不同路径
function add_font_r(file, size, bold, last_code) {
    if (is_undefined(last_code)) last_code = 0xFFFF;

    var f = font_add("resources/" + file, size, bold, false, 0, last_code);
    if (f < 0) f = font_add("datafiles/resources/" + file, size, bold, false, 0, last_code);
    if (f < 0) f = font_add(file, size, bold, false, 0, last_code);
    if (f < 0) f = font_add("datafiles/" + file, size, bold, false, 0, last_code);

    // 极端情况下（resources 丢失）回退到系统字体，尽量保证程序仍可运行
    if (f < 0) {
        var windir = environment_get_variable("WINDIR");
        if (windir != "") {
            f = font_add(windir + "/Fonts/msyh.ttc", size, bold, false, 0, last_code);
            if (f < 0) f = font_add(windir + "/Fonts/simhei.ttf", size, bold, false, 0, last_code);
        }
    }

    return f;
}

/// @function ui_ensure_fonts()
/// @description 确保主字体（Minecraft）已创建；SimHei 改为按需加载
function ui_ensure_fonts() {
    var created_mc = false;
    if (!variable_global_exists("font_mc")) {
        // Minecraft 字体只需要覆盖 ASCII、符号与 CJK（<= 0x9FFF）；
        // 0x9FFF 以上的字形不会被 font_char_uses_mc 选中，加载它们只会拖慢启动。
        global.font_mc = add_font_r("Minecraft.ttf", 12, false, 0x9FFF);
        created_mc = true;
    }
    if (!variable_global_exists("font_cn")) {
        global.font_cn = -2;
    }
    if (!variable_global_exists("font1") || created_mc) {
        global.font1 = global.font_mc;
    }
}

/// @function ui_cn_font()
/// @description 按需加载 SimHei（仅当出现非中日韩文字时）
function ui_cn_font() {
    if (!variable_global_exists("font_cn")) {
        ui_ensure_fonts();
    }
    if (global.font_cn == -2) {
        global.font_cn = add_font_r("simhei.ttf", 12, false, 0xFFFF);
        if (global.font_cn >= 0) {
            global.font1 = global.font_cn;
        }
    }
    return (global.font_cn >= 0) ? global.font_cn : global.font_mc;
}

/// @function font_char_uses_mc(code)
/// @description 中文（含繁体）和英文/数字/常用符号使用 Minecraft，其余语言字母使用 SimHei
function font_char_uses_mc(code) {
    if (code < 128) return true;                       // ASCII / 英文
    if (code >= 0x3400 && code <= 0x4DBF) return true; // CJK 扩展 A
    if (code >= 0x4E00 && code <= 0x9FFF) return true; // CJK 统一表意文字（含繁体）
    if (code >= 0xF900 && code <= 0xFAFF) return true; // CJK 兼容表意文字
    if (code >= 0x20000 && code <= 0x2FA1F) return true; // CJK 扩展 B 及以上
    if (code >= 0x3000 && code <= 0x303F) return true; // 中文标点
    if (code >= 0xFF00 && code <= 0xFFEF) return true; // 全角字符
    if (code >= 0x2000 && code <= 0x2BFF) return true; // 常用符号
    return false;                                      // 其他语言字母 -> SimHei
}

/// @function string_width_mixed(text, font_mc, font_cn)
/// @description 按混合字体规则计算文本宽度
function string_width_mixed(text, font_mc, font_cn) {
    if (text == "") return 0;

    var old_font = draw_get_font();
    var total = 0;
    var len = string_length(text);
    var current_mc = true;
    var run = "";

    for (var i = 1; i <= len; i++) {
        var ch = string_char_at(text, i);
        var use_mc = font_char_uses_mc(string_ord_at(text, i));

        if (use_mc != current_mc && run != "") {
            draw_set_font(current_mc ? font_mc : ui_cn_font());
            total += string_width(run);
            run = "";
        }

        current_mc = use_mc;
        run += ch;
    }

    if (run != "") {
        draw_set_font(current_mc ? font_mc : ui_cn_font());
        total += string_width(run);
    }

    draw_set_font(old_font);
    return total;
}

/// @function draw_text_mixed(x, y, text, font_mc, font_cn, line_height)
/// @description 按混合字体规则绘制文本（支持 \n 换行和当前对齐方式）
function draw_text_mixed(x, y, text, font_mc, font_cn, line_height) {
    if (text == "") return;

    var old_font = draw_get_font();
    var old_halign = draw_get_halign();
    var old_valign = draw_get_valign();
    var lines = string_split(text, "\n");
    var line_count = array_length(lines);
    var single_line = (line_count == 1);
    var draw_y = y;

    if (!single_line) {
        if (old_valign == fa_middle) {
            draw_y = y - (line_count * line_height) * 0.5;
        } else if (old_valign == fa_bottom) {
            draw_y = y - line_count * line_height;
        }
    }

    for (var li = 0; li < line_count; li++) {
        var line = lines[li];
        var total_w = string_width_mixed(line, font_mc, font_cn);
        var start_x = x;

        if (old_halign == fa_center) {
            start_x = x - total_w * 0.5;
        } else if (old_halign == fa_right) {
            start_x = x - total_w;
        }

        var cx = start_x;
        var len = string_length(line);
        var current_mc = true;
        var run = "";

        draw_set_halign(fa_left);
        draw_set_valign(single_line ? old_valign : fa_top);
        for (var i = 1; i <= len; i++) {
            var ch = string_char_at(line, i);
            var use_mc = font_char_uses_mc(string_ord_at(line, i));

            if (use_mc != current_mc && run != "") {
                draw_set_font(current_mc ? font_mc : ui_cn_font());
                draw_text(cx, single_line ? y : draw_y + li * line_height, run);
                cx += string_width(run);
                run = "";
            }

            current_mc = use_mc;
            run += ch;
        }

        if (run != "") {
            draw_set_font(current_mc ? font_mc : ui_cn_font());
            draw_text(cx, single_line ? y : draw_y + li * line_height, run);
        }
        draw_set_halign(fa_left);
    }

    draw_set_font(old_font);
    draw_set_halign(old_halign);
    draw_set_valign(old_valign);
}

/// @function is_cjk_code(code)
/// @description 判断码位是否属于 CJK 表意文字
function is_cjk_code(code) {
    return (code >= 0x3400 && code <= 0x4DBF) ||
           (code >= 0x4E00 && code <= 0x9FFF) ||
           (code >= 0xF900 && code <= 0xFAFF) ||
           (code >= 0x20000 && code <= 0x2FA1F);
}

/// @function ensure_pinyin_map()
/// @description 懒加载 datafiles/pinyin.txt 到全局 ds_map（汉字 -> 无音调拼音）
function ensure_pinyin_map() {
    if (variable_global_exists("pinyin_map")) {
        if (global.pinyin_map != -1) return;
    }

    global.pinyin_map = ds_map_create();

    // 用 buffer_load 一次性读入，比逐行 file_text_read_string 快很多
    var paths = [
        "resources/pinyin.txt",
        "datafiles/resources/pinyin.txt",
        "pinyin.txt",
        "datafiles/pinyin.txt"
    ];
    // 优先使用二进制内嵌的 pinyin.txt，外部文件仅作为开发时的后备
    var text = embedded_pinyin_text();

    if (text == "") {
        for (var font_file_idx = 0; font_file_idx < array_length(paths); font_file_idx++) {
            if (!file_exists(paths[font_file_idx])) continue;

            var loaded = buffer_load(paths[font_file_idx]);
            if (loaded == -1) continue;

            var buf_size = buffer_get_size(loaded);
            var buf = buffer_create(buf_size + 1, buffer_grow, 1);
            buffer_copy(loaded, 0, buf_size, buf, 0);
            buffer_delete(loaded);

            // buffer_string 需要 \0 结尾
            buffer_seek(buf, buffer_seek_start, buf_size);
            buffer_write(buf, buffer_u8, 0);
            buffer_seek(buf, buffer_seek_start, 0);
            text = buffer_read(buf, buffer_string);
            buffer_delete(buf);
            break;
        }
    }

    if (text == "") {
        show_debug_message("pinyin.txt 未找到，中文将按字符码排序");
        return;
    }

    var lines = string_split(text, "\n");
    var line_count = array_length(lines);

    for (var li = 0; li < line_count; li++) {
        var line = string_replace_all(lines[li], "\r", "");
        if (line == "") continue;

        var tab = string_pos("\t", line);
        if (tab <= 0) continue;

        var ch = string_copy(line, 1, tab - 1);
        var py = string_copy(line, tab + 1, string_length(line) - tab);

        if (ch != "" && py != "") {
            ds_map_add(global.pinyin_map, ch, py);
        }
    }
}

/// @function pinyin_sort_key(text)
/// @description 生成拼音/字母排序键
function pinyin_sort_key(text) {
    ensure_pinyin_map();

    var key = "";
    var len = string_length(text);

    for (var i = 1; i <= len; i++) {
        var ch = string_char_at(text, i);
        var code = string_ord_at(text, i);

        if (is_cjk_code(code)) {
            var py = ds_map_find_value(global.pinyin_map, ch);
            if (is_undefined(py) || py == "") {
                py = string_lower(ch);
            }
            key += py;
        } else {
            key += string_lower(ch);
        }
    }

    return key;
}

/// @function sort_key_less(a, b)
/// @description 按码位比较两个排序键
function sort_key_less(a, b) {
    var n = min(string_length(a), string_length(b));

    for (var i = 1; i <= n; i++) {
        var ca = string_ord_at(a, i);
        var cb = string_ord_at(b, i);
        if (ca < cb) return true;
        if (ca > cb) return false;
    }

    return string_length(a) < string_length(b);
}

/// @function ui_back_rect()
/// @description 左上角返回按钮的矩形 [x1, y1, x2, y2]
function ui_back_rect() {
    return [8, 4, 34, 30];
}

/// @function draw_ui_back_button(hover)
/// @description 绘制左上角返回按钮（单图标、无文字）
function draw_ui_back_button(hover) {
    var r = ui_back_rect();

    if (hover) {
        draw_set_color(make_color_rgb(90, 96, 120));
    } else {
        draw_set_color(make_color_rgb(55, 58, 72));
    }
    draw_set_alpha(hover ? 0.40 : 0.30);
    draw_simple_rounded_rect(r[0], r[1], r[2], r[3], 6, false);
    draw_set_alpha(1.0);

    draw_set_color(make_color_rgb(40, 42, 55));
    draw_simple_rounded_rect(r[0], r[1], r[2], r[3], 6, true);

    // 左箭头图标
    var cx = (r[0] + r[2]) * 0.5;
    var cy = (r[1] + r[3]) * 0.5;
    draw_set_color(hover ? c_white : make_color_rgb(215, 220, 235));
    draw_line_width(cx + 5, cy, cx - 4, cy, 2);
    draw_line_width(cx - 1, cy - 4, cx - 5, cy, 2);
    draw_line_width(cx - 1, cy + 4, cx - 5, cy, 2);

    draw_set_color(c_white);
}

/// @function ui_refresh_rect()
/// @description 返回按钮右侧刷新按钮的矩形
function ui_refresh_rect() {
    return [42, 4, 68, 30];
}

/// @function draw_ui_refresh_button(hover)
/// @description 绘制刷新按钮（单图标、无文字）
function draw_ui_refresh_button(hover) {
    var r = ui_refresh_rect();

    if (hover) {
        draw_set_color(make_color_rgb(90, 96, 120));
    } else {
        draw_set_color(make_color_rgb(55, 58, 72));
    }
    draw_set_alpha(hover ? 0.40 : 0.30);
    draw_simple_rounded_rect(r[0], r[1], r[2], r[3], 6, false);
    draw_set_alpha(1.0);

    draw_set_color(make_color_rgb(40, 42, 55));
    draw_simple_rounded_rect(r[0], r[1], r[2], r[3], 6, true);

    var cx = (r[0] + r[2]) * 0.5;
    var cy = (r[1] + r[3]) * 0.5;
    var icon_color = hover ? c_white : make_color_rgb(215, 220, 235);

    // 圆环
    draw_set_color(icon_color);
    draw_circle(cx, cy, 7, true);

    // 顺时针箭头
    draw_set_color(icon_color);
    draw_triangle(cx + 4, cy - 9, cx + 10, cy - 5, cx + 3, cy - 2, false);

    draw_set_color(c_white);
}

/// @function ui_more_rect()
function ui_more_rect() {
    return [600, 4, 626, 30];
}

/// @function ui_chat_more_rect()
function ui_chat_more_rect() {
    return ui_more_rect();
}

/// @function ui_about_link_rect()
function ui_about_link_rect() {
    return [232, 130, 600, 158];
}

/// @function ui_about_close_rect()
function ui_about_close_rect() {
    return [496, 306, 584, 338];
}

/// @function draw_ui_more_button(hover)
/// @description 右上角“更多信息”按钮（三个横向圆点）
function draw_ui_more_button(hover) {
    var r = ui_more_rect();

    if (hover) {
        draw_set_color(make_color_rgb(90, 96, 120));
    } else {
        draw_set_color(make_color_rgb(55, 58, 72));
    }
    draw_set_alpha(hover ? 0.40 : 0.30);
    draw_simple_rounded_rect(r[0], r[1], r[2], r[3], 6, false);
    draw_set_alpha(1.0);

    var cx = (r[0] + r[2]) * 0.5;
    var cy = (r[1] + r[3]) * 0.5;
    draw_set_color(hover ? c_white : make_color_rgb(215, 220, 235));
    draw_circle(cx - 6, cy, 2, false);
    draw_circle(cx, cy, 2, false);
    draw_circle(cx + 6, cy, 2, false);

    draw_set_color(c_white);
}

/// @function ui_chat_send_rect()
function ui_chat_send_rect() {
    return [540, 354, 628, 384];
}

/// @function ui_info_close_rect()
function ui_info_close_rect() {
    return [270, 300, 370, 332];
}

/// @function draw_ui_button(x1, y1, x2, y2, label, hover, base_r, base_g, base_b)
/// @description 通用圆角文字按钮
function draw_ui_button(x1, y1, x2, y2, label, hover, base_r, base_g, base_b) {
    if (hover) {
        draw_set_color(make_color_rgb(min(255, base_r + 35), min(255, base_g + 45), min(255, base_b + 45)));
    } else {
        draw_set_color(make_color_rgb(base_r, base_g, base_b));
    }
    draw_set_alpha(hover ? 0.40 : 0.30);
    draw_simple_rounded_rect(x1, y1, x2, y2, 6, false);
    draw_set_alpha(1.0);

    draw_set_color(make_color_rgb(max(0, base_r - 18), max(0, base_g - 35), max(0, base_b - 55)));
    draw_simple_rounded_rect(x1, y1, x2, y2, 6, true);

    draw_set_font(font1);
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text_mixed((x1 + x2) * 0.5, (y1 + y2) * 0.5, label, font_mc, font1, 20);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
}

/// @function ui_name_dialog_rects()
/// @description 命名弹窗布局（面板 / 输入框 / 确定 / 取消）
function ui_name_dialog_rects() {
    var panel = [110, 100, 530, 300];
    var field = [panel[0] + 24, panel[1] + 74, panel[2] - 24, panel[1] + 114];
    var ok = [panel[2] - 200, panel[3] - 54, panel[2] - 120, panel[3] - 18];
    var cancel = [panel[2] - 105, panel[3] - 54, panel[2] - 25, panel[3] - 18];
    return { panel: panel, field: field, ok: ok, cancel: cancel };
}

/// @function ui_name_dialog_update_text(text, max_chars)
/// @description 处理键盘输入与退格，返回更新后的文本
function ui_name_dialog_update_text(text, max_chars) {
    var typed = keyboard_string;
    if (typed != "") {
        typed = string_replace_all(string_replace_all(typed, "\r", ""), "\n", "");
        text += typed;
        keyboard_string = "";
    }

    // 支持 Ctrl+V 粘贴（也方便输入法不可用时输入中文）
    if (keyboard_check(vk_control) && keyboard_check_pressed(ord("V"))) {
        var clip = clipboard_has_text() ? clipboard_get_text() : "";
        if (clip != "") {
            clip = string_replace_all(string_replace_all(clip, "\r", ""), "\n", "");
            text += clip;
        }
    }

    if (string_length(text) > max_chars) {
        text = string_copy(text, 1, max_chars);
    }

    if (keyboard_check_pressed(vk_backspace) && string_length(text) > 0) {
        text = string_delete(text, string_length(text), 1);
    }

    return text;
}

/// @function draw_ui_name_dialog(title, prompt, text, error, ok_hover, cancel_hover)
/// @description 绘制命名弹窗（含输入框、错误提示、确定/取消按钮）
function draw_ui_name_dialog(title, prompt, text, error, ok_hover, cancel_hover) {
    var r = ui_name_dialog_rects();
    var p = r.panel;
    var f = r.field;

    // 半透明遮罩
    draw_set_alpha(0.65);
    draw_set_color(c_black);
    draw_rectangle(0, 0, 640, 400, false);
    draw_set_alpha(1);

    // 面板
    draw_set_color(make_color_rgb(36, 40, 52));
    draw_simple_rounded_rect(p[0], p[1], p[2], p[3], 10, false);
    draw_set_color(make_color_rgb(90, 110, 145));
    draw_simple_rounded_rect(p[0], p[1], p[2], p[3], 10, true);

    draw_set_font(font1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_mixed(p[0] + 24, p[1] + 18, title, font_mc, font1, 20);

    draw_set_color(make_color_rgb(180, 195, 220));
    draw_text_mixed(p[0] + 24, p[1] + 46, prompt, font_mc, font1, 20);

    // 输入框
    draw_set_color(make_color_rgb(22, 25, 34));
    draw_rectangle(f[0], f[1], f[2], f[3], false);
    draw_set_color(make_color_rgb(100, 120, 155));
    draw_rectangle(f[0], f[1], f[2], f[3], true);

    draw_set_color(c_white);
    var shown = text;
    var max_w = (f[2] - f[0]) - 20;
    while (string_length(shown) > 0 && string_width_mixed(shown, font_mc, font1) > max_w) {
        shown = string_delete(shown, 1, 1);
    }
    draw_text_mixed(f[0] + 10, f[1] + 11, shown, font_mc, font1, 20);

    // 闪烁光标
    if (((current_time div 500) mod 2) == 0) {
        var cx = f[0] + 10 + string_width_mixed(shown, font_mc, font1);
        draw_rectangle(cx, f[1] + 9, cx + 1, f[3] - 9, false);
    }

    // 错误提示
    if (error != "") {
        draw_set_color(make_color_rgb(255, 130, 130));
        draw_text_mixed(p[0] + 24, p[1] + 124, error, font_mc, font1, 20);
    }

    // 按钮
    draw_ui_button(r.ok[0], r.ok[1], r.ok[2], r.ok[3], "确定", ok_hover, 58, 120, 185);
    draw_ui_button(r.cancel[0], r.cancel[1], r.cancel[2], r.cancel[3], "取消", cancel_hover, 75, 78, 95);

    draw_set_color(c_white);
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}
