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

// 标题文字 - 添加对name变量的安全检查
draw_set_font(font1);
draw_set_color(c_white);
draw_set_halign(fa_center);

// 安全地显示名称，如果name未定义则显示"未知"
var display_name = name;
if (!is_string(name) || name == "") {
    display_name = "不到啊";
}
draw_text(320, 20, "当前个人名称 " + display_name);
draw_set_halign(fa_left);

// 绘制消息显示区域（在紫色框内再画一个深色区域用于显示消息）
draw_set_color(make_color_rgb(600, 100, 600)); // 深紫色
draw_rectangle(15, 50, 625, 325, true); // 消息显示区域

// 绘制聊天消息 - 添加空值检查
if (ds_exists(Talkstr_list, ds_type_list)) {
    var message_count = ds_list_size(Talkstr_list);
    
    // 设置剪裁区域，确保消息只在深色区域内显示
    gpu_set_scissor(15, 50, 610, 275); // 宽度610，高度275
    
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
                var prefix_width = string_width(user_line) + 10; // 用户名宽度+10像素边距
                if (string_width(test_line) > 580 - prefix_width) {
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
                if (string_width(test_line) > 580) {
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
                        draw_text(20, y_pos, user_part);
                        
                        // 绘制消息部分（白色）
                        var message_part = string_copy(line_text, colon_pos_in_line + 1, string_length(line_text) - colon_pos_in_line);
                        var user_width = string_width(user_part);
                        draw_set_color(c_white); // 消息颜色
                        draw_text(20 + user_width, y_pos, message_part);
                    } else {
                        // 如果没有冒号，按原样绘制
                        draw_set_color(message_color);
                        draw_text(20, y_pos, line_text);
                    }
                } else {
                    // 后续行（消息内容的换行）
                    draw_set_color(c_white); // 消息颜色
                    draw_text(20, y_pos, lines[line_idx]);
                }
            } else {
                // 非用户消息（系统消息等）
                draw_set_color(message_color);
                draw_text(20, y_pos, lines[line_idx]);
            }
            
            // 确保不会超出显示区域
            if (y_pos >= 325) {
                break;
            }
        }
    }
    
    
    // 恢复剪裁设置
    gpu_set_scissor(false);
    
} else {
    // 如果列表还未创建，显示提示
    draw_set_color(make_color_rgb(150, 150, 170));
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(320, 180, "正尝试联机至房间\n\n如果你看到了这个界面\n那么大概率连不上了\n建议关掉当前窗口重连");
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