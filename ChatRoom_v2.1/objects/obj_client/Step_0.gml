// 处理发送消息
if(keyboard_check_pressed(vk_enter) || (keyboard_check(vk_alt) && keyboard_check_pressed(ord("S")))) {
    sendmes = name + ":" + textbox_return(textbox_1);
    if(sendmes != name + ":") {
        var buf;
        buf = buffer_create(10000,buffer_fixed,4);
        buffer_write(buf,buffer_string,sendmes);
        network_send_raw(socket,buf,buffer_get_size(buf));
        buffer_delete(buf);
        
        // 发送后清空文本框内容 - 使用正确的方法
        // 方法1：销毁并重新创建文本框
        if (instance_exists(textbox_1)) {
            instance_destroy(textbox_1);
        }
        textbox_1 = textbox_create(0, 360, 640, 20, "", "按下 Enter 或 Alt+S 以发送消息", 120, true, false);
        textbox_set_font(textbox_1, font1, c_white, 18, 1.5);
    }
}

