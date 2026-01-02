/// @function draw_buttons(hover_create, hover_join, button_pressed, button1_x, button1_y, button2_x, button2_y, button_width, button_height, button_radius)
/// @description 绘制主界面的交互式按钮（简化版）

function draw_buttons(
    _hover_create, 
    _hover_join, 
    _button_pressed,
    _button1_x,
    _button1_y,
    _button2_x,
    _button2_y,
    _button_width,
    _button_height,
    _button_radius
) {
    // 性能优化：使用局部变量存储常用值
    var _btn1_right = _button1_x + _button_width;
    var _btn1_bottom = _button1_y + _button_height;
    var _btn2_right = _button2_x + _button_width;
    var _btn2_bottom = _button2_y + _button_height;
    var _btn1_center_x = _button1_x + _button_width / 2;
    var _btn1_center_y = _button1_y + _button_height / 2;
    var _btn2_center_x = _button2_x + _button_width / 2;
    var _btn2_center_y = _button2_y + _button_height / 2;
    
    // 确定按钮状态和颜色
    var btn1_color, btn2_color, btn1_alpha, btn2_alpha;
    
    // 简化的状态判断：只有悬停和正常状态
    if (_hover_create) {
        btn1_color = color_button_hover;
        btn1_alpha = button_alpha_hover;
    } else {
        btn1_color = color_button_normal;
        btn1_alpha = button_alpha_normal;
    }
    
    if (_hover_join) {
        btn2_color = color_button_hover;
        btn2_alpha = button_alpha_hover;
    } else {
        btn2_color = color_button_normal;
        btn2_alpha = button_alpha_normal;
    }
    
    // 如果按钮被按下，使用按下状态
    if (_button_pressed && _hover_create) {
        btn1_color = color_button_pressed;
        btn1_alpha = button_alpha_pressed;
    }
    
    if (_button_pressed && _hover_join) {
        btn2_color = color_button_pressed;
        btn2_alpha = button_alpha_pressed;
    }
    
    // 绘制第一个按钮主体（简化版，移除阴影）
    draw_set_colour(btn1_color);
    draw_set_alpha(btn1_alpha);
    draw_roundrect_ext(_button1_x, _button1_y, 
                      _btn1_right, _btn1_bottom, 
                      _button_radius, _button_radius, true);
    
    // 绘制按钮边框（简化边框透明度）
    draw_set_colour(color_button_border);
    draw_set_alpha(0.8); // 边框稍透明
    draw_roundrect_ext(_button1_x, _button1_y, 
                      _btn1_right, _btn1_bottom, 
                      _button_radius, _button_radius, false);
    
    // 绘制按钮文字
    draw_set_font(font1);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_colour(color_button_text);
    draw_set_alpha(1);
    draw_text(_btn1_center_x, _btn1_center_y, "创建聊天室");
    
    // 绘制第二个按钮主体
    draw_set_colour(btn2_color);
    draw_set_alpha(btn2_alpha);
    draw_roundrect_ext(_button2_x, _button2_y, 
                      _btn2_right, _btn2_bottom, 
                      _button_radius, _button_radius, true);
    
    // 绘制按钮边框
    draw_set_colour(color_button_border);
    draw_set_alpha(0.8);
    draw_roundrect_ext(_button2_x, _button2_y, 
                      _btn2_right, _btn2_bottom, 
                      _button_radius, _button_radius, false);
    
    // 绘制按钮文字
    draw_set_colour(color_button_text);
    draw_set_alpha(1);
    draw_text(_btn2_center_x, _btn2_center_y, "加入聊天室");
    
    // 重置绘制设置
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);
}