// 绘制背景（使用Sprite2）
if (sprite_exists(Sprite2)) {
    var bg_width = sprite_get_width(Sprite2);
    var bg_height = sprite_get_height(Sprite2);
    var scale_x = 640 / bg_width;
    var scale_y = 400 / bg_height;
    draw_sprite_ext(Sprite2, 0, 0, 0, scale_x, scale_y, 0, c_white, 1);
} else {
    draw_set_color(c_black);
    draw_rectangle(0, 0, room_width, room_height, false);
}

// ===== 左上角返回按钮（单图标，先于消息裁剪绘制）=====
var back = ui_back_rect();
var back_hover = point_in_rectangle(mouse_x, mouse_y, back[0], back[1], back[2], back[3]);
draw_ui_back_button(back_hover);

// ===== 左上角标题：房间名称（用户名）=====
var room_display = client_room_name;
if (!is_string(room_display) || room_display == "") {
    room_display = "聊天室";
}
var user_display = name;
if (!is_string(user_display) || user_display == "") {
    user_display = "未命名";
}

var title_text = room_display + "（" + user_display + "）";
var title_max_w = 540;
if (string_width_mixed(title_text, font_mc, font1) > title_max_w) {
    while (string_length(title_text) > 0 &&
           string_width_mixed(title_text + "...", font_mc, font1) > title_max_w) {
        title_text = string_delete(title_text, string_length(title_text), 1);
    }
    title_text += "...";
}

draw_set_font(font1);
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_text_mixed(44, 10, title_text, font_mc, font1, 20);

// ===== 右上角更多信息按钮 =====
var more_rect = ui_chat_more_rect();
var more_hover = point_in_rectangle(mouse_x, mouse_y, more_rect[0], more_rect[1], more_rect[2], more_rect[3]);
draw_ui_more_button(more_hover);

// 绘制消息显示区域（在紫色框内再画一个深色区域用于显示消息）
draw_set_color(make_color_rgb(600, 100, 600)); // 深紫色
draw_rectangle(15, 50, 625, 325, true); // 消息显示区域

// 绘制聊天消息 - 添加空值检查
if (ds_exists(Talkstr_list, ds_type_list)) {
    var message_count = ds_list_size(Talkstr_list);
    
    // 绘制消息
    var start_y = 55;
    var max_lines_to_show = 13; // 大约可以显示13行（275/20≈13.75）
    
    // 从列表末尾开始绘制最新的消息
    var start_index = max(0, message_count - max_lines_to_show);
    
    for(var i = start_index; i < message_count; i++) {
        var message = Talkstr_list[| i];
        var skiptext = 0;
        
        // 默认消息颜色为白色
        var message_color = c_white;
        
        if(string_copy(message, 0, 6) == "&coly=") {
            // 系统消息（黄色）
            message_color = c_yellow;
            skiptext = 6;
        }
        
        var text_content = string_copy(message, skiptext + 1, string_length(message) - skiptext);
        
        // 判断是否是用户消息（格式：用户名:消息内容）
        var colon_pos = string_pos(":", text_content);
        var is_user_message = colon_pos > 0;
        
        // 处理长文本换行显示（手动换行）
        var lines = [];
        var current_line = "";
        
        // 如果是用户消息，需要特殊处理用户名和消息内容
        if (is_user_message) {
            var user_name = string_copy(text_content, 1, colon_pos - 1);
            var user_message = string_copy(text_content, colon_pos + 1, string_length(text_content) - colon_pos);
            
            // 第一行：用户名（特定颜色）
            var user_line = user_name + ":";
            lines = [user_line];
            
            // 处理消息内容的换行
            var message_lines = [];
            current_line = "";
            var words = string_split(user_message, " ");
            
            for(var w = 0; w < array_length(words); w++) {
                var test_line = current_line;
                if (string_length(test_line) > 0) {
                    test_line += " " + words[w];
                } else {
                    test_line = words[w];
                }
                
                // 检查行宽（用户名部分已经占了宽度）
                var prefix_width = string_width_mixed(user_line, font_mc, font1) + 10; // 用户名宽度+10像素边距
                if (string_width_mixed(test_line, font_mc, font1) > 580 - prefix_width) {
                    // 如果加上这个词会超宽，开始新的一行
                    if (string_length(current_line) > 0) {
                        array_push(message_lines, current_line);
                        current_line = words[w];
                    } else {
                        // 单个词就超长了，需要截断
                        array_push(message_lines, string_copy(words[w], 1, 30) + "...");
                        current_line = "";
                    }
                } else {
                    current_line = test_line;
                }
            }
            
            // 添加最后一行
            if (string_length(current_line) > 0) {
                array_push(message_lines, current_line);
            }
            
            // 合并行
            if (array_length(message_lines) > 0) {
                // 第一行已经包含用户名，所以合并第一行消息内容
                lines[0] = user_line + " " + message_lines[0];
                
                // 添加剩余的消息行
                for(var m = 1; m < array_length(message_lines); m++) {
                    // 后续行需要缩进，以对齐消息内容
                    var indent = string("            "); // 大约12个空格用于缩进
                    array_push(lines, indent + message_lines[m]);
                }
            } else {
                // 只有用户名，没有消息内容
                lines[0] = user_line;
            }
        } else {
            // 非用户消息（系统消息等）
            var words = string_split(text_content, " ");
            
            for(var w = 0; w < array_length(words); w++) {
                var test_line = current_line;
                if (string_length(test_line) > 0) {
                    test_line += " " + words[w];
                } else {
                    test_line = words[w];
                }
                
                // 检查行宽
                if (string_width_mixed(test_line, font_mc, font1) > 580) {
                    // 如果加上这个词会超宽，开始新的一行
                    if (string_length(current_line) > 0) {
                        array_push(lines, current_line);
                        current_line = words[w];
                    } else {
                        // 单个词就超长了，需要截断
                        array_push(lines, string_copy(words[w], 1, 30) + "...");
                        current_line = "";
                    }
                } else {
                    current_line = test_line;
                }
            }
            
            // 添加最后一行
            if (string_length(current_line) > 0) {
                array_push(lines, current_line);
            }
            
            // 如果lines为空（可能是空消息），添加一个空行
            if (array_length(lines) == 0) {
                array_push(lines, "");
            }
        }
        
        // 绘制每一行
        var line_count = array_length(lines);
        for(var line_idx = 0; line_idx < line_count; line_idx++) {
            var y_pos = start_y + ((i - start_index) * 20) + (line_idx * 20);

            // 超出消息区域就不再绘制（替代 scissor，避免裁剪状态泄漏）
            if (y_pos + 20 > 325) break;
            
            // 根据行类型设置颜色
            if (is_user_message) {
                // 第一行：用户名部分特殊颜色，消息部分白色
                if (line_idx == 0) {
                    var line_text = lines[line_idx];
                    var colon_pos_in_line = string_pos(":", line_text);
                    
                    if (colon_pos_in_line > 0) {
                        // 绘制用户名部分（特殊颜色）
                        var user_part = string_copy(line_text, 1, colon_pos_in_line);
                        draw_set_color(make_color_rgb(180, 200, 220)); // 用户名颜色
                        draw_text_mixed(20, y_pos, user_part, font_mc, font1, 20);
                        
                        // 绘制消息部分（白色）
                        var message_part = string_copy(line_text, colon_pos_in_line + 1, string_length(line_text) - colon_pos_in_line);
                        var user_width = string_width_mixed(user_part, font_mc, font1);
                        draw_set_color(c_white); // 消息颜色
                        draw_text_mixed(20 + user_width, y_pos, message_part, font_mc, font1, 20);
                    } else {
                        // 如果没有冒号，按原样绘制
                        draw_set_color(message_color);
                        draw_text_mixed(20, y_pos, line_text, font_mc, font1, 20);
                    }
                } else {
                    // 后续行（消息内容的换行）
                    draw_set_color(c_white); // 消息颜色
                    draw_text_mixed(20, y_pos, lines[line_idx], font_mc, font1, 20);
                }
            } else {
                // 非用户消息（系统消息等）
                draw_set_color(message_color);
                draw_text_mixed(20, y_pos, lines[line_idx], font_mc, font1, 20);
            }
            
        }
    }
    
} else {
    // 如果列表还未创建，显示提示
    draw_set_color(make_color_rgb(150, 150, 170));
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text_mixed(320, 180, "正尝试联机至房间\n\n如果你看到了这个界面\n那么大概率连不上了\n建议关掉当前窗口重连", font_mc, font1, 20);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

var message_count = 0;
if (ds_exists(Talkstr_list, ds_type_list)) {
    message_count = ds_list_size(Talkstr_list);
}

draw_set_color(c_white);
draw_set_halign(fa_left);
var msg_count = ds_exists(Talkstr_list, ds_type_list) ? ds_list_size(Talkstr_list) : 0;
draw_text(10, 10, " ");

// 恢复默认颜色
draw_set_color(c_white);

// ===== 聊天输入框背景与发送按钮 =====
draw_set_color(make_color_rgb(24, 28, 38));
draw_simple_rounded_rect(8, 352, 532, 386, 8, false);
draw_set_color(make_color_rgb(80, 90, 115));
draw_simple_rounded_rect(8, 352, 532, 386, 8, true);

var send_rect = ui_chat_send_rect();
var send_hover = point_in_rectangle(mouse_x, mouse_y,
    send_rect[0], send_rect[1], send_rect[2], send_rect[3]);
draw_ui_button(send_rect[0], send_rect[1], send_rect[2], send_rect[3],
               "发送", send_hover, 58, 120, 185);

// ===== 昵称设置弹窗 =====
if (naming_active) {
    var rects = ui_name_dialog_rects();
    var ok_hover = point_in_rectangle(mouse_x, mouse_y,
        rects.ok[0], rects.ok[1], rects.ok[2], rects.ok[3]);
    var cancel_hover = point_in_rectangle(mouse_x, mouse_y,
        rects.cancel[0], rects.cancel[1], rects.cancel[2], rects.cancel[3]);
    draw_ui_name_dialog("设置昵称", "请输入你的昵称（不能为空）",
                        name_text, name_error, ok_hover, cancel_hover);
}

// ===== 房间信息弹窗 =====
if (info_active) {
    draw_set_alpha(0.65);
    draw_set_color(c_black);
    draw_rectangle(0, 0, 640, 400, false);
    draw_set_alpha(1.0);

    var px1 = 90;
    var py1 = 70;
    var px2 = 550;
    var py2 = 350;

    draw_set_color(make_color_rgb(30, 35, 48));
    draw_simple_rounded_rect(px1, py1, px2, py2, 10, false);
    draw_set_color(make_color_rgb(90, 110, 145));
    draw_simple_rounded_rect(px1, py1, px2, py2, 10, true);

    draw_set_font(font1);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_text_mixed(px1 + 20, py1 + 16, "房间信息", font_mc, font1, 20);

    draw_set_color(make_color_rgb(80, 100, 130));
    draw_line(px1 + 16, py1 + 44, px2 - 16, py1 + 44);

    var info_room = client_room_name;
    if (!is_string(info_room) || info_room == "") info_room = "聊天室";
    if (string_length(info_room) > 20) info_room = string_copy(info_room, 1, 20) + "...";

    var info_id = client_room_id;
    if (!is_string(info_id) || info_id == "") {
        info_id = client_connect_server + ":" + string_format(client_connect_port, 1, 0);
    }

    var info_server = client_connect_server;
    if (client_connect_port != 6510) {
        info_server += ":" + string_format(client_connect_port, 1, 0);
    }

    var info_user = name;
    if (!is_string(info_user) || info_user == "") info_user = "未命名";

    var connected_seconds = max(0, (current_time - connect_time) / 1000);
    var connected_min = floor(connected_seconds / 60);
    var connected_sec = floor(connected_seconds % 60);

    var info_lines = [
        "房间名称: " + info_room,
        "房间标识: " + info_id,
        "服务器地址: " + info_server,
        "当前在线: " + string(max(1, online_count)) + " 人",
        "我的昵称: " + info_user,
        "连接状态: 已连接",
        "已连接时长: " + string_format(connected_min, 2, 0) + "分" + string_format(connected_sec, 2, 0) + "秒"
    ];

    var line_y = py1 + 58;
    for (var li = 0; li < array_length(info_lines); li++) {
        draw_text_mixed(px1 + 20, line_y + li * 22, info_lines[li], font_mc, font1, 22);
    }

    var close_rect = ui_info_close_rect();
    var close_hover = point_in_rectangle(mouse_x, mouse_y,
        close_rect[0], close_rect[1], close_rect[2], close_rect[3]);
    draw_ui_button(close_rect[0], close_rect[1], close_rect[2], close_rect[3],
                   "关闭", close_hover, 75, 78, 95);

    draw_set_color(c_white);
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

draw_set_color(c_white);
draw_set_alpha(1);
