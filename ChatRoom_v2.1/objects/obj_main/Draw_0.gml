// 绘制背景（使用预计算的缩放比例）
draw_sprite_ext(spr_background, 0, 0, 0, scale_x, scale_y, 0, c_white, 1);

// 绘制标题文字（使用预创建的字体）
draw_set_font(font_title);
draw_set_colour(color_title);
draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_text(320, 35, "简易聊天室");

// 绘制说明文字背景（使用优化版圆角矩形）
draw_set_colour(c_black);
draw_set_alpha(text_bg_alpha);
draw_simple_rounded_rect(60, 80, 580, 240, 8, false); // 使用优化函数

// 绘制文字
draw_set_alpha(1);
draw_set_colour(color_text);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_text_ext(80, 90, "\n注意事项：\n> 如果在聊天室中无法发送消息\n> 可能是网络连接中断\n> 或服务器暂时不可用", 20, 320);

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
draw_text(630, 396, "v2.1");

// 重置绘制设置
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_white);
draw_set_alpha(1);