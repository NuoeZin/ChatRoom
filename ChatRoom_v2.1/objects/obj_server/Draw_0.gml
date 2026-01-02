// 清除屏幕并绘制背景
if (sprite_exists(Sprite2)) {
    var bg_width = sprite_get_width(Sprite2);
    var bg_height = sprite_get_height(Sprite2);
    var scale_x = room_width / bg_width;
    var scale_y = room_height / bg_height;
    draw_sprite_ext(Sprite2, 0, 0, 0, scale_x, scale_y, 0, c_white, 1);
} else {
    // 如果没有Sprite2，使用黑色背景
    draw_set_color(c_black);
    draw_rectangle(0, 0, room_width, room_height, false);
}

// 计算在线用户数量
var user_count = min(ds_list_size(ip_list), ds_list_size(name_list));

// 计算已开启时间（秒）
var uptime_seconds = (current_time - room_start_time) / 1000;
var uptime_hours = floor(uptime_seconds / 3600);
var uptime_minutes = floor((uptime_seconds % 3600) / 60);
var uptime_secs = floor(uptime_seconds % 60);
var uptime_str = string_format(uptime_hours, 2, 0) + "h:" + 
                 string_format(uptime_minutes, 2, 0) + "m:" + 
                 string_format(uptime_secs, 2, 0 )+ "s";



// ========== 左上角：聊天室名称 ==========
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_text(10, 10, "聊天室名称: " + servername);

// ========== 右上角：状态信息 ==========
var status_x = room_width - 10;
var status_y = 10;


// 显示状态信息
draw_set_color(make_color_rgb(200, 220, 255)); // 柔和蓝色文字
draw_set_halign(fa_right);
draw_text(status_x, status_y, "在线人数: " + string(user_count) + "人");
draw_text(status_x, status_y + 15, "已开启时间: " + uptime_str);
draw_set_halign(fa_left);

// ========== 绘制主内容区域背景 ==========
var content_x = 10;
var content_y = 80;
var content_width = room_width - 20;
var content_height = room_height - 140;

// 主内容区背景（柔和深色）
draw_set_color(make_color_rgb(30, 35, 45));
draw_set_alpha(0.6);
draw_rectangle(content_x, content_y, 
               content_x + content_width, content_y + content_height, true);
draw_set_alpha(1.0);

// 边框
draw_set_color(make_color_rgb(60, 70, 90));
draw_rectangle(content_x, content_y, 
               content_x + content_width, content_y + content_height, false);

// ========== 绘制用户列表标题 ==========
var title_y = content_y + 10;
draw_set_color(make_color_rgb(220, 230, 255)); // 柔和白色
draw_text(content_x + 15, title_y, "在线用户列表 (" + string(user_count) + "人)");

// 标题分隔线
draw_set_color(make_color_rgb(80, 100, 130));
draw_line(content_x + 10, title_y + 20, 
          content_x + content_width - 10, title_y + 20);

// ========== 绘制用户列表 ==========
if (user_count > 0) {
    var list_start_y = title_y + 30;
    var list_end_y = content_y + content_height - 20;
    var row_spacing = 24;
    var max_rows = floor((list_end_y - list_start_y) / row_spacing);
    var display_count = min(user_count, max_rows);
    
    // 表头背景（柔和蓝色）
    draw_set_color(make_color_rgb(60, 75, 100));
    draw_set_alpha(0.7);
    draw_rectangle(content_x + 10, list_start_y - 5, 
                   content_x + content_width - 10, list_start_y + 25, true);
    draw_set_alpha(1.0);
    
    // 表头文字
    draw_set_color(make_color_rgb(180, 200, 240)); // 柔和青色
    draw_text(content_x + 20, list_start_y + 5, "序号");
    draw_text(content_x + 70, list_start_y + 5, "用户名");
    draw_text(content_x + 440, list_start_y + 5, "IP地址");
    
    // 表头分隔线
    draw_set_color(make_color_rgb(80, 100, 130));
    draw_line(content_x + 10, list_start_y + 25, 
              content_x + content_width - 10, list_start_y + 25);
    
    // 显示用户列表
    for(var i = 0; i < display_count; i++) {
        var actual_index = i;
        var ip_address = ip_list[| actual_index];
        var user_name = name_list[| actual_index];
        var y_position = list_start_y + 30 + (i * row_spacing);
        
        // 交替行背景色（柔和）
        draw_set_alpha(0.4);
        if (i % 2 == 0) {
            draw_set_color(make_color_rgb(40, 50, 65)); // 柔和深蓝
        } else {
            draw_set_color(make_color_rgb(35, 45, 60)); // 柔和深蓝（稍暗）
        }
        draw_rectangle(content_x + 12, y_position - 3, 
                       content_x + content_width - 12, y_position + row_spacing - 8, false);
        draw_set_alpha(1.0);
        
        // 绘制序号
        draw_set_color(make_color_rgb(180, 200, 220)); // 柔和灰色
        draw_text(content_x + 20, y_position + 3, "#" + string(actual_index + 1));
        
        // 绘制用户名（添加长度限制）
        var display_name = user_name;
        if (string_length(user_name) > 15) {
            display_name = string_copy(user_name, 1, 15) + "...";
        }
        draw_set_color(make_color_rgb(220, 240, 255)); // 柔和白色
        draw_text(content_x + 70, y_position + 3, display_name);
        
        // 绘制IP地址
        draw_set_color(make_color_rgb(180, 200, 240)); // 柔和蓝色
        draw_text(content_x + 360, y_position + 3, ip_address);
        
    }
    
    // 如果用户数超过显示范围，显示提示
    if (user_count > display_count) {
        draw_set_color(make_color_rgb(240, 160, 160)); // 柔和红色提示
        draw_set_halign(fa_center);
        draw_text(content_x + content_width/2, 
                 list_start_y + 30 + (display_count * row_spacing) + 10,
                 "除以上者外，还有 " + string(user_count - display_count) + " 个用户未显示");
        draw_set_halign(fa_left);
    }
} else {
    draw_set_color(make_color_rgb(150, 170, 190)); // 柔和灰色
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(content_x + content_width/2, 
              content_y + content_height/2, 
              "当前没有任何人在线");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}


// ========== 绘制状态栏 ==========
var statusbar_y = room_height - 25;
draw_set_color(make_color_rgb(50, 60, 75)); // 深蓝色背景
draw_set_alpha(0.8);
draw_rectangle(0, statusbar_y, room_width, room_height, false);
draw_set_alpha(1.0);

// 状态栏文字
draw_set_color(make_color_rgb(180, 200, 220)); // 柔和白色
draw_set_halign(fa_left);
draw_text(10, statusbar_y + 5, "房主连接到自己的聊天室请输入: localhost 或 127.0.0.1");

draw_set_halign(fa_right);
draw_text(room_width - 10, statusbar_y + 5, "按ESC关房");

// ========== 恢复默认设置 ==========
draw_set_color(c_white);
draw_set_halign(fa_left);
draw_set_alpha(1.0);