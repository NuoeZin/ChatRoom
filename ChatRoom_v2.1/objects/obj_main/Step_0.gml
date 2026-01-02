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

