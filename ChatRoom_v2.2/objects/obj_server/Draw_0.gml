// 统一使用中文字体，避免继承到不含中文的默认字体
draw_set_font(font1);

// ===== 背景 =====
if (sprite_exists(Sprite2)) {
    var bg_width = sprite_get_width(Sprite2);
    var bg_height = sprite_get_height(Sprite2);
    draw_sprite_ext(Sprite2, 0, 0, 0, room_width / bg_width, room_height / bg_height, 0, c_white, 1);
} else {
    draw_set_color(c_black);
    draw_rectangle(0, 0, room_width, room_height, false);
}

// ===== 房间命名弹窗 =====
if (naming_active) {
    var _rects = ui_name_dialog_rects();
    var _ok_hover = point_in_rectangle(mouse_x, mouse_y,
        _rects.ok[0], _rects.ok[1], _rects.ok[2], _rects.ok[3]);
    var _cancel_hover = point_in_rectangle(mouse_x, mouse_y,
        _rects.cancel[0], _rects.cancel[1], _rects.cancel[2], _rects.cancel[3]);
    draw_ui_name_dialog("创建聊天室", "请为聊天室取一个名称（不能为空）",
                        name_text, name_error, _ok_hover, _cancel_hover);
    exit;
}

// ===== 在线人数 / 运行时间 =====
var user_count = min(ds_list_size(ip_list), ds_list_size(name_list));

var uptime_seconds = (current_time - room_start_time) / 1000;
var uptime_hours = floor(uptime_seconds / 3600);
var uptime_minutes = floor((uptime_seconds % 3600) / 60);
var uptime_secs = floor(uptime_seconds % 60);
var uptime_str = string_format(uptime_hours, 2, 0) + "h:" +
                 string_format(uptime_minutes, 2, 0) + "m:" +
                 string_format(uptime_secs, 2, 0) + "s";

// 左上角：聊天室名称
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_text_mixed(10, 10, "聊天室名称: " + servername, font_mc, font1, 20);

// 右上角：状态信息
var status_x = room_width - 10;
draw_set_color(make_color_rgb(200, 220, 255));
draw_set_halign(fa_right);
draw_text_mixed(status_x, 10, "在线人数: " + string(user_count) + "人", font_mc, font1, 20);
draw_text_mixed(status_x, 25, "已开启时间: " + uptime_str, font_mc, font1, 20);
draw_set_halign(fa_left);

// ===== 主内容区域 =====
var content_x = 10;
var content_y = 80;
var content_width = room_width - 20;
var content_height = room_height - 140;

draw_set_color(make_color_rgb(30, 35, 45));
draw_set_alpha(0.6);
draw_rectangle(content_x, content_y,
               content_x + content_width, content_y + content_height, true);
draw_set_alpha(1.0);

draw_set_color(make_color_rgb(60, 70, 90));
draw_rectangle(content_x, content_y,
               content_x + content_width, content_y + content_height, false);

// ===== 布局参数 =====
var title_y = content_y + 10;                       // 90
var rows_start_y = title_y + 30;                    // 120（表头）
var data_start_y = rows_start_y + 30;               // 150（数据行）
var rows_end_y = content_y + content_height - 20;   // 320
var row_spacing = 24;
var visible_rows = max(1, floor((rows_end_y - data_start_y) / row_spacing));  // 7
var max_row = max(0, user_count - visible_rows);

member_scroll_row = clamp(member_scroll_row, 0, max_row);

// ===== 标题 =====
draw_set_color(make_color_rgb(220, 230, 255));
draw_set_halign(fa_left);
draw_text_mixed(content_x + 15, title_y, "在线用户列表 (" + string(user_count) + "人)", font_mc, font1, 20);

draw_set_color(make_color_rgb(80, 100, 130));
draw_line(content_x + 10, title_y + 20,
          content_x + content_width - 10, title_y + 20);

if (user_count > 0) {
    // ===== 表头 =====
    draw_set_color(make_color_rgb(60, 75, 100));
    draw_set_alpha(0.7);
    draw_rectangle(content_x + 10, rows_start_y - 5,
                   content_x + content_width - 10, rows_start_y + 25, false);
    draw_set_alpha(1.0);

    draw_set_color(make_color_rgb(180, 200, 240));
    draw_text_mixed(content_x + 20, rows_start_y + 5, "序号", font_mc, font1, 20);
    draw_text_mixed(content_x + 70, rows_start_y + 5, "用户名", font_mc, font1, 20);
    draw_text_mixed(content_x + 360, rows_start_y + 5, "IP地址", font_mc, font1, 20);

    draw_set_color(make_color_rgb(80, 100, 130));
    draw_line(content_x + 10, rows_start_y + 25,
              content_x + content_width - 10, rows_start_y + 25);

    // 数据区背景
    draw_set_color(make_color_rgb(25, 30, 40));
    draw_set_alpha(0.5);
    draw_rectangle(content_x + 10, data_start_y - 4,
                   content_x + content_width - 10, rows_end_y, false);
    draw_set_alpha(1.0);

    // ===== 绘制可见成员行 =====
    for (var i = 0; i < visible_rows; i++) {
        var idx = member_scroll_row + i;
        if (idx >= user_count) break;

        var y_position = data_start_y + i * row_spacing;
        var ip_address = ip_list[| idx];
        var user_name = name_list[| idx];

        // 交替行背景色
        draw_set_alpha(0.4);
        if (idx % 2 == 0) {
            draw_set_color(make_color_rgb(40, 50, 65));
        } else {
            draw_set_color(make_color_rgb(35, 45, 60));
        }
        draw_rectangle(content_x + 12, y_position - 3,
                       content_x + content_width - 12, y_position + row_spacing - 8, false);
        draw_set_alpha(1.0);

        // 序号
        draw_set_color(make_color_rgb(180, 200, 220));
        draw_text_mixed(content_x + 20, y_position + 3, "#" + string(idx + 1), font_mc, font1, 20);

        // 用户名（限制显示长度）
        var display_name = user_name;
        if (display_name == "") {
            display_name = "(加入中...)";
        } else if (string_length(display_name) > 15) {
            display_name = string_copy(display_name, 1, 15) + "...";
        }
        draw_set_color(make_color_rgb(220, 240, 255));
        draw_text_mixed(content_x + 70, y_position + 3, display_name, font_mc, font1, 20);

        // IP 地址
        draw_set_color(make_color_rgb(180, 200, 240));
        draw_text_mixed(content_x + 360, y_position + 3, ip_address, font_mc, font1, 20);
    }

    // ===== 滚动条 =====
    if (max_row > 0) {
        var sb_x = content_x + content_width - 5;
        var sb_top = data_start_y;
        var sb_bottom = rows_end_y;
        var sb_h = sb_bottom - sb_top;
        var thumb_h = max(24, sb_h * visible_rows / user_count);
        var thumb_y = sb_top + (sb_h - thumb_h) * (member_scroll_row / max_row);

        draw_set_color(make_color_rgb(50, 50, 62));
        draw_set_alpha(0.6);
        draw_rectangle(sb_x, sb_top, sb_x + 4, sb_bottom, false);
        draw_set_alpha(1.0);

        draw_set_color(make_color_rgb(125, 125, 155));
        draw_rectangle(sb_x, thumb_y, sb_x + 4, thumb_y + thumb_h, false);
    }
} else {
    draw_set_color(make_color_rgb(150, 170, 190));
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text_mixed(content_x + content_width / 2,
                    content_y + content_height / 2,
                    "当前没有任何人在线", font_mc, font1, 20);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ===== 底部状态栏 =====
var statusbar_y = room_height - 25;
draw_set_color(make_color_rgb(50, 60, 75));
draw_set_alpha(0.8);
draw_rectangle(0, statusbar_y, room_width, room_height, false);
draw_set_alpha(1.0);

draw_set_color(make_color_rgb(180, 200, 220));
draw_set_halign(fa_left);
draw_text_mixed(10, statusbar_y + 5, "房主连接到自己的聊天室请输入: localhost 或 127.0.0.1", font_mc, font1, 20);

draw_set_halign(fa_right);
draw_text_mixed(room_width - 10, statusbar_y + 5, "按ESC关房", font_mc, font1, 20);

// ===== 恢复默认状态 =====
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);
