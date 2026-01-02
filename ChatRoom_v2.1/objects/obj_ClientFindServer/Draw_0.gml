// 绘制背景（如果有Sprite2背景图片）
if (sprite_exists(Sprite2)) {
    var bg_width = sprite_get_width(Sprite2);
    var bg_height = sprite_get_height(Sprite2);
    var scale_x = 640 / bg_width;
    var scale_y = 400 / bg_height;
    draw_sprite_ext(Sprite2, 0, 0, 0, scale_x, scale_y, 0, c_white, 1);
}

// 绘制标题栏
draw_set_color(make_color_rgb(40, 40, 50));
draw_set_alpha(0.8);
draw_rectangle(0, 0, 640, 35, true);
draw_set_alpha(1.0);

// 标题文字
draw_set_font(font1);
draw_set_color(c_white);
draw_set_halign(fa_center);
draw_text(320, 10, "                                聊天室列表             点击左边区域手动输入IP");
draw_set_halign(fa_left);

// 提示文字
draw_set_color(make_color_rgb(180, 180, 220));
draw_text(10, 10, "点击我以手动联机！");

// 服务器列表区域
var server_count = ds_list_size(server_list);
var list_x = 20;
var list_width = 600;
var list_y = list_start_y;
var list_end_y = 380;

// 列表背景
draw_set_color(make_color_rgb(30, 30, 40));
draw_set_alpha(0.7);
draw_rectangle(list_x, list_y, list_x + list_width, list_end_y, true);
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(80, 80, 100));
draw_rectangle(list_x, list_y, list_x + list_width, list_end_y, false);

// 检查是否有服务器
if (server_count == 0) {
    draw_set_color(make_color_rgb(150, 150, 170));
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(320, 200, "正在搜索服务器...\n如果没有发现服务器，请点击上方区域手动连接");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
} else {
    // 绘制每个服务器项
    for(var i = 0; i < server_count; i++) {
        var item_y = list_y + i * list_item_height;
        var item_bottom = item_y + list_item_height;
        
        // 检查是否超出显示区域
        if (item_bottom > list_end_y) break;
        
        // 检查鼠标悬停
        var mouse_over = (mouse_x >= list_x && mouse_x <= list_x + list_width &&
                         mouse_y >= item_y && mouse_y <= item_bottom);
        
        // 绘制列表项背景（淡灰色矩形框）
        if (mouse_over) {
            // 悬停状态
            draw_set_color(make_color_rgb(100, 100, 120));
        } else {
            // 正常状态（交替颜色）
            if (i % 2 == 0) {
                draw_set_color(make_color_rgb(70, 70, 90));
            } else {
                draw_set_color(make_color_rgb(60, 60, 80));
            }
        }
        
        draw_set_alpha(0.8);
        draw_rectangle(list_x, item_y, list_x + list_width, item_bottom, true);
        draw_set_alpha(1.0);
        
        // 边框
        draw_set_color(make_color_rgb(90, 90, 110));
        draw_rectangle(list_x, item_y, list_x + list_width, item_bottom, false);
        
        // 服务器信息
        var ip = server_list[| i];
        var name = server_names[| i];
        
        // IP地址（较大字体）
        draw_set_color(c_white);
        draw_set_font(font_add("simhei.ttf", 14, false, false, 0, 60000));
        draw_text(list_x + list_padding, item_y + 10, "IP: " + ip);
        
        // 服务器名称
        draw_set_color(make_color_rgb(200, 200, 220));
        draw_set_font(font_add("simhei.ttf", 12, false, false, 0, 60000));
        draw_text(list_x + list_padding, item_y + 32, "名称: " + name);
        
        // 最后活跃时间（如果有）
        if (ds_map_exists(server_last_seen, ip)) {
            var last_seen = ds_map_find_value(server_last_seen, ip);
            var time_ago = current_time - last_seen;
            
            draw_set_color(make_color_rgb(150, 150, 170));
            draw_set_font(font_add("simhei.ttf", 10, false, false, 0, 60000));
            
            if (time_ago < 10000) {
                draw_text(list_x + 450, item_y + 15, "刚刚活跃");
            } else {
                draw_text(list_x + 450, item_y + 15, "活跃: " + string(time_ago div 1000) + "秒前");
            }
        }
        
        // 悬停提示
        if (mouse_over) {
            draw_set_color(make_color_rgb(100, 200, 100));
            draw_set_halign(fa_right);
            draw_text(list_x + list_width - list_padding, item_y + 30, "点击连接 →");
            draw_set_halign(fa_left);
        }
        
        // 恢复默认字体
        draw_set_font(font1);
    }
}

draw_set_color(make_color_rgb(180, 180, 220));
draw_set_halign(fa_center);
draw_text(320, 381, "发现 " + string(server_count) + " 个服务器 | 双击或点击连接");
draw_set_halign(fa_left);

draw_set_color(c_white);