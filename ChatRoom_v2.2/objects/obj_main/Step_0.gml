// ===== 更多信息 / 关于对话框 =====
if (more_active) {
    var close_rect = ui_about_close_rect();
    var link_rect = ui_about_link_rect();

    if (keyboard_check_pressed(vk_escape) ||
        (mouse_check_button_pressed(mb_left) &&
         point_in_rectangle(mouse_x, mouse_y, close_rect[0], close_rect[1], close_rect[2], close_rect[3]))) {
        more_active = false;
        exit;
    }

    if (mouse_check_button_pressed(mb_left) &&
        point_in_rectangle(mouse_x, mouse_y, link_rect[0], link_rect[1], link_rect[2], link_rect[3])) {
        clipboard_set_text(more_url);
        more_copied_until = current_time + 2000;
        exit;
    }

    exit;
}

// 右上角更多按钮
if (mouse_check_button_pressed(mb_left)) {
    var more_rect = ui_more_rect();
    if (point_in_rectangle(mouse_x, mouse_y, more_rect[0], more_rect[1], more_rect[2], more_rect[3])) {
        more_active = true;
        more_copied_until = 0;
        alarm[0] = -1;

        // 首次打开时再解码内嵌图片，避免拖慢启动
        if (!about_img_loaded) {
            if (!variable_global_exists("about_img")) {
                global.about_img = load_embedded_my_drink();
            }
            more_img = global.about_img;
            about_img_loaded = true;
        }
        exit;
    }
}

// 检测鼠标悬停状态（恢复每帧检测，因为已经简化）
hover_create = (mouse_x >= button1_left && mouse_x <= button1_right && 
               mouse_y >= button1_top && mouse_y <= button1_bottom);
               
hover_join = (mouse_x >= button2_left && mouse_x <= button2_right && 
             mouse_y >= button2_top && mouse_y <= button2_bottom);

// 检测鼠标按下
if (mouse_check_button_pressed(mb_left)) {
    button_pressed = true;
    
    if (hover_create) {
        // 按钮按下效果延迟
        alarm[0] = 5; // 5帧后跳转，提供视觉反馈
    } else if (hover_join) {
        alarm[0] = 5; // 5帧后跳转，提供视觉反馈
    }
}

// 检测鼠标释放
if (mouse_check_button_released(mb_left)) {
    button_pressed = false;
}

