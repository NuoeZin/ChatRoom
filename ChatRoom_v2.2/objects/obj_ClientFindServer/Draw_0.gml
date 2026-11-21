// ===== 背景 =====
if (sprite_exists(Sprite2)) {
    var bg_width = sprite_get_width(Sprite2);
    var bg_height = sprite_get_height(Sprite2);
    draw_sprite_ext(Sprite2, 0, 0, 0, 640 / bg_width, 400 / bg_height, 0, c_white, 1);
}

// ===== 标题栏 =====
draw_set_font(font1);
draw_set_color(make_color_rgb(40, 40, 50));
draw_set_alpha(0.85);
draw_rectangle(0, 0, 640, 35, false);
draw_set_alpha(1.0);

// 左上角：返回主界面（单图标）
var back = ui_back_rect();
var back_hover = point_in_rectangle(mouse_x, mouse_y, back[0], back[1], back[2], back[3]);
draw_ui_back_button(back_hover);

// 返回按钮右侧：刷新列表
var refresh = ui_refresh_rect();
var refresh_hover = point_in_rectangle(mouse_x, mouse_y, refresh[0], refresh[1], refresh[2], refresh[3]);
draw_ui_refresh_button(refresh_hover);

if (current_time < refresh_flash_until) {
    draw_set_halign(fa_left);
    draw_set_font(font1);
    draw_set_color(make_color_rgb(120, 220, 150));
    draw_text_mixed(74, 11, "已刷新", font_mc, font1, 20);
}

// 标题
draw_set_color(c_white);
draw_set_halign(fa_center);
draw_text_mixed(320, 10, "聊天室列表", font_mc, font1, 20);
draw_set_halign(fa_left);

// 右上角：手动连接按钮
var manual_x1 = 528;
var manual_y1 = 5;
var manual_x2 = 632;
var manual_y2 = 30;
var manual_hover = point_in_rectangle(mouse_x, mouse_y, manual_x1, manual_y1, manual_x2, manual_y2);
draw_ui_button(manual_x1, manual_y1, manual_x2, manual_y2, "手动连接", manual_hover, 58, 120, 185);

// ===== 列表区域 =====
var server_count = ds_list_size(server_list);
var list_end_y = list_y + list_height;
var max_row = max(0, server_count - list_visible_rows);
list_scroll_row = clamp(list_scroll_row, 0, max_row);

// 列表背景
draw_set_color(make_color_rgb(28, 28, 38));
draw_set_alpha(0.92);
draw_rectangle(list_x, list_y, list_x + list_width, list_end_y, false);
draw_set_alpha(1.0);

if (server_count == 0) {
    draw_set_color(make_color_rgb(150, 150, 170));
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text_mixed(320, 200, "正在搜索服务器...\n如果没有发现服务器，请点击右上角「手动连接」", font_mc, font1, 20);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
} else {
    var btn_x = list_x + list_width - btn_width - btn_margin;
    var draw_row = 0;
    var row_h = (list_item_height > 0) ? list_item_height : 56;

    for (var i = 0; i < list_visible_rows; i++) {
        var idx = list_scroll_row + draw_row;
        if (idx >= server_count) break;

        var item_y = list_y + draw_row * row_h;
        var item_bottom = item_y + row_h;
        var b_y = item_y + (row_h - btn_height) * 0.5;

        var mouse_over = point_in_rectangle(mouse_x, mouse_y, list_x, item_y,
                                            list_x + list_width, item_bottom);
        var btn_hover = point_in_rectangle(mouse_x, mouse_y, btn_x, b_y,
                                           btn_x + btn_width, b_y + btn_height);

        // 行背景（交替色 + 悬停高亮）
        if (mouse_over) {
            draw_set_color(make_color_rgb(95, 95, 115));
        } else if (idx % 2 == 0) {
            draw_set_color(make_color_rgb(68, 68, 88));
        } else {
            draw_set_color(make_color_rgb(58, 58, 78));
        }
        draw_set_alpha(0.85);
        draw_rectangle(list_x + 1, item_y, list_x + list_width - 1, item_bottom, false);
        draw_set_alpha(1.0);

        var key = server_list[| idx];
        var ip = ds_map_exists(server_ip_map, key) ? ds_map_find_value(server_ip_map, key) : key;
        var port = ds_map_exists(server_port_map, key) ? ds_map_find_value(server_port_map, key) : 6510;
        var name = server_names[| idx];
        if (name == "") name = "(未命名房间)";
        var name_max_w = 268;
        if (string_width_mixed(name, font_mc, font1) > name_max_w) {
            while (string_length(name) > 0 &&
                   string_width_mixed(name + "...", font_mc, font1) > name_max_w) {
                name = string_delete(name, string_length(name), 1);
            }
            name += "...";
        }

        // 房间名称（上方）
        draw_set_font(font1);
        draw_set_color(c_white);
        draw_text_mixed(list_x + list_padding, item_y + 6, name, font_mc, font1, 20);

        // IP 地址（名称下方）
        draw_set_font(font1);
        draw_set_color(make_color_rgb(150, 170, 210));
        var ip_text = "IP: " + ip;
        if (port != 6510) {
            ip_text += ":" + string_format(port, 1, 0);
        }
        draw_text_mixed(list_x + list_padding, item_y + 31, ip_text, font_mc, font1, 20);

        // 同名房间显示短 ID，方便区分不同房间
        if (string_length(key) == 20 && string_pos(":", key) == 0) {
            var dup_count = 0;
            for (var d = 0; d < server_count; d++) {
                if (server_names[| d] == server_names[| idx]) dup_count++;
            }

            if (dup_count > 1) {
                draw_set_font(font1);
                draw_set_color(make_color_rgb(150, 155, 180));
                draw_text_mixed(list_x + 180, item_y + 33,
                                "ID: " + string_copy(key, 1, 6), font_mc, font1, 20);
            }
        }

        // 在线人数（纯数字，右对齐在活跃度下方）
        if (ds_map_exists(server_player_counts, key)) {
            var pcount = ds_map_find_value(server_player_counts, key);
            if (pcount >= 0) {
                draw_set_font(font1);
                draw_set_color(make_color_rgb(100, 220, 150));
                draw_set_halign(fa_right);
                draw_text_mixed(btn_x - 16, item_y + 31, string(pcount), font_mc, font1, 20);
                draw_set_halign(fa_left);
            }
        }

        // 最后活跃时间（右对齐到连接按钮左侧）
        if (ds_map_exists(server_last_seen, key)) {
            var time_ago = current_time - ds_map_find_value(server_last_seen, key);
            draw_set_color(make_color_rgb(140, 145, 165));
            draw_set_font(font1);
            draw_set_halign(fa_right);
            if (time_ago < 10000) {
                draw_text_mixed(btn_x - 16, item_y + 9, "刚刚活跃", font_mc, font1, 20);
            } else {
                draw_text_mixed(btn_x - 16, item_y + 9, "活跃 " + string(time_ago div 1000) + " 秒前", font_mc, font1, 20);
            }
            draw_set_halign(fa_left);
        }

        // 信息区与按钮之间的细分隔线
        draw_set_color(make_color_rgb(80, 80, 100));
        draw_line(btn_x - 10, item_y + 9, btn_x - 10, item_bottom - 9);

        // 右侧「连接」按钮（唯一加入入口）
        draw_ui_button(btn_x, b_y, btn_x + btn_width, b_y + btn_height,
                       "连接", btn_hover, 58, 120, 185);

        // 行分隔线
        draw_set_color(make_color_rgb(78, 78, 98));
        draw_line(list_x + 1, item_bottom, list_x + list_width - 1, item_bottom);

        draw_row++;
    }

    // ===== 滚动条 =====
    if (max_row > 0) {
        var sb_x = list_x + list_width - 4;
        var sb_top = list_y + 2;
        var sb_bottom = list_end_y - 2;
        var sb_h = sb_bottom - sb_top;
        var thumb_h = max(24, sb_h * list_visible_rows / server_count);
        var thumb_y = sb_top + (sb_h - thumb_h) * (list_scroll_row / max_row);

        // 轨道
        draw_set_color(make_color_rgb(50, 50, 62));
        draw_set_alpha(0.6);
        draw_rectangle(sb_x, sb_top, sb_x + 4, sb_bottom, false);
        draw_set_alpha(1.0);

        // 滑块
        draw_set_color(make_color_rgb(125, 125, 155));
        draw_rectangle(sb_x, thumb_y, sb_x + 4, thumb_y + thumb_h, false);
    }
}

// 列表边框
draw_set_color(make_color_rgb(80, 80, 100));
draw_rectangle(list_x, list_y, list_x + list_width, list_end_y, true);

// ===== 底部状态栏 =====
draw_set_font(font1);
draw_set_color(make_color_rgb(180, 180, 220));
draw_set_halign(fa_center);
draw_text_mixed(320, 384, "发现 " + string(server_count) + " 个服务器  |  点击右侧「连接」按钮加入", font_mc, font1, 20);
draw_set_halign(fa_left);

// ===== 恢复默认状态 =====
draw_set_color(c_white);
draw_set_alpha(1.0);

// ===== 连接前连通性检查遮罩 =====
if (join_checking) {
    draw_set_alpha(0.65);
    draw_set_color(c_black);
    draw_rectangle(0, 0, 640, 400, false);
    draw_set_alpha(1.0);

    draw_set_font(font1);
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    var target_text = client_connect_server;
    if (client_connect_port != 6510) {
        target_text += ":" + string_format(client_connect_port, 1, 0);
    }
    draw_text_mixed(320, 195, "正在连接 " + target_text + " ...", font_mc, font1, 20);
    draw_set_color(make_color_rgb(180, 195, 220));
    draw_text_mixed(320, 218, "如果没有响应，将拒绝加入该房间", font_mc, font1, 20);
    draw_set_halign(fa_left);
}

// ===== 加入房间前的昵称弹窗 =====
if (join_name_active) {
    var rects = ui_name_dialog_rects();
    var ok_hover = point_in_rectangle(mouse_x, mouse_y,
        rects.ok[0], rects.ok[1], rects.ok[2], rects.ok[3]);
    var cancel_hover = point_in_rectangle(mouse_x, mouse_y,
        rects.cancel[0], rects.cancel[1], rects.cancel[2], rects.cancel[3]);
    draw_ui_name_dialog("加入聊天室", "请输入你的昵称（不能为空）",
                        join_name_text, join_name_error, ok_hover, cancel_hover);
}

// ===== 手动连接 IP 弹窗 =====
if (manual_ip_active) {
    var ip_rects = ui_name_dialog_rects();
    var ip_ok_hover = point_in_rectangle(mouse_x, mouse_y,
        ip_rects.ok[0], ip_rects.ok[1], ip_rects.ok[2], ip_rects.ok[3]);
    var ip_cancel_hover = point_in_rectangle(mouse_x, mouse_y,
        ip_rects.cancel[0], ip_rects.cancel[1], ip_rects.cancel[2], ip_rects.cancel[3]);
    draw_ui_name_dialog("手动连接", "输入 IP 或 IP:端口（如 192.168.1.5:7000）",
                        manual_ip_text, manual_ip_error, ip_ok_hover, ip_cancel_hover);
}
