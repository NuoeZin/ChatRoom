// 绘制背景（使用预计算的缩放比例）
draw_sprite_ext(spr_background, 0, 0, 0, scale_x, scale_y, 0, c_white, 1);

// 绘制标题文字（使用预创建的字体）
draw_set_font(font1);
draw_set_colour(color_title);
draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_text_mixed(320, 35, "简易聊天室", font_mc, font1, 20);

// 绘制说明文字背景（使用优化版圆角矩形）
draw_set_colour(c_black);
draw_set_alpha(text_bg_alpha);
draw_simple_rounded_rect(60, 80, 580, 240, 8, false); // 使用优化函数

// 绘制文字
draw_set_alpha(1);
draw_set_colour(color_text);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_text_mixed(80, 90, "\n注意事项：\n> 如果在聊天室中无法发送消息\n> 可能是网络连接中断\n> 或服务器暂时不可用", font_mc, font1, 20);

// 绘制按钮
draw_buttons(
    hover_create,
    hover_join,
    button_pressed,
    button1_x,
    button_y,
    button2_x,
    button_y,
    button_width,
    button_height,
    button_radius
);

// 绘制版本信息
draw_set_font(font1);
draw_set_colour(color_version);
draw_set_halign(fa_right);
draw_set_valign(fa_bottom);
draw_text_mixed(630, 396, "v2.2", font_mc, font1, 20);

// ===== 右上角更多信息按钮 =====
var more_rect = ui_more_rect();
var more_hover = point_in_rectangle(mouse_x, mouse_y,
    more_rect[0], more_rect[1], more_rect[2], more_rect[3]);
draw_ui_more_button(more_hover);

// ===== 关于 / GitHub 对话框 =====
if (more_active) {
    draw_set_alpha(0.65);
    draw_set_color(c_black);
    draw_rectangle(0, 0, 640, 400, false);
    draw_set_alpha(1.0);

    var px1 = 36;
    var py1 = 52;
    var px2 = 604;
    var py2 = 348;

    draw_set_color(make_color_rgb(30, 35, 48));
    draw_simple_rounded_rect(px1, py1, px2, py2, 10, false);
    draw_set_color(make_color_rgb(90, 110, 145));
    draw_simple_rounded_rect(px1, py1, px2, py2, 10, true);

    draw_set_font(font1);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_text_mixed(px1 + 20, py1 + 14, "关于本软件", font_mc, font1, 20);

    draw_set_color(make_color_rgb(80, 100, 130));
    draw_line(px1 + 16, py1 + 44, px2 - 16, py1 + 44);

    // 左侧内嵌图片
    var img_x = 60;
    var img_y = 104;
    var img_size = 160;
    if (more_img >= 0) {
        var iw = sprite_get_width(more_img);
        var ih = sprite_get_height(more_img);
        var img_scale = min(img_size / iw, img_size / ih);
        var dw = iw * img_scale;
        var dh = ih * img_scale;
        draw_sprite_ext(more_img, 0,
                        img_x + (img_size - dw) * 0.5,
                        img_y + (img_size - dh) * 0.5,
                        img_scale, img_scale, 0, c_white, 1);
    } else {
        draw_set_color(make_color_rgb(40, 45, 60));
        draw_rectangle(img_x, img_y, img_x + img_size, img_y + img_size, false);
        draw_set_color(make_color_rgb(150, 150, 170));
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text_mixed(img_x + img_size * 0.5, img_y + img_size * 0.5,
                        "图片加载失败", font_mc, font1, 20);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }

    // 图片与右侧信息之间的分隔线
    draw_set_color(make_color_rgb(70, 86, 112));
    draw_line(228, 108, 228, 300);

    // 右侧 GitHub 链接
    var text_x = 236;
    var link_rect = ui_about_link_rect();
    var link_hover = point_in_rectangle(mouse_x, mouse_y,
        link_rect[0], link_rect[1], link_rect[2], link_rect[3]);

    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(font1);
    draw_text_mixed(text_x, 106, "GitHub 仓库", font_mc, font1, 20);

    var link_color = link_hover ? make_color_rgb(120, 200, 255) : make_color_rgb(90, 160, 240);
    draw_set_color(link_color);
    // 超链接全部为 ASCII，可直接用单字体绘制；过宽时自动缩放，绝不超出面板
    draw_set_font(font_mc);
    var url_w = string_width_mixed(more_url, font_mc, font1);
    var url_max_w = px2 - 20 - text_x;
    var url_scale = (url_w > url_max_w) ? (url_max_w / url_w) : 1;
    draw_text_transformed(text_x, 134, more_url, url_scale, 1, 0);
    draw_line(text_x, 152, text_x + url_w * url_scale, 152);

    draw_set_color(make_color_rgb(170, 175, 195));
    draw_text_mixed(text_x, 166, "简单的本地局域网聊天室程序", font_mc, font1, 20);

    if (current_time < more_copied_until) {
        draw_set_color(make_color_rgb(110, 225, 150));
        draw_set_halign(fa_center);
        draw_text_mixed(img_x + img_size * 0.5, img_y + img_size + 14,
                        "超链接已复制", font_mc, font1, 20);
        draw_set_halign(fa_left);
    }

    draw_set_color(make_color_rgb(150, 155, 175));
    draw_text_mixed(text_x, 222, "软件版本: v2.2", font_mc, font1, 20);

    var close_rect = ui_about_close_rect();
    var close_hover = point_in_rectangle(mouse_x, mouse_y,
        close_rect[0], close_rect[1], close_rect[2], close_rect[3]);
    draw_ui_button(close_rect[0], close_rect[1], close_rect[2], close_rect[3],
                   "关闭", close_hover, 75, 78, 95);

    draw_set_color(c_white);
    draw_set_alpha(1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// 重置绘制设置
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_white);
draw_set_alpha(1);
