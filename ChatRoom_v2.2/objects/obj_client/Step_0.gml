// ===== 房间信息弹窗 =====
if (info_active) {
    global.chat_input_blocked = true;
    var close_rect = ui_info_close_rect();

    if (keyboard_check_pressed(vk_escape) ||
        (mouse_check_button_pressed(mb_left) &&
         point_in_rectangle(mouse_x, mouse_y, close_rect[0], close_rect[1], close_rect[2], close_rect[3]))) {
        info_active = false;
        global.chat_input_blocked = false;
        create_chat_textbox(chat_draft);
        chat_draft = "";
    }

    exit;
}

// ===== 昵称设置弹窗 =====
if (naming_active) {
    name_text = ui_name_dialog_update_text(name_text, name_max_length);

    var rects = ui_name_dialog_rects();
    var ok_click = mouse_check_button_pressed(mb_left) &&
        point_in_rectangle(mouse_x, mouse_y, rects.ok[0], rects.ok[1], rects.ok[2], rects.ok[3]);
    var cancel_click = mouse_check_button_pressed(mb_left) &&
        point_in_rectangle(mouse_x, mouse_y, rects.cancel[0], rects.cancel[1], rects.cancel[2], rects.cancel[3]);

    if (ok_click || keyboard_check_pressed(vk_enter)) {
        var trimmed = string_trim(name_text);

        if (trimmed == "") {
            name_error = "昵称不能为空";
        } else {
            name = trimmed;
            name_error = "";

            var name_buf;
            name_buf = buffer_create(10000, buffer_fixed, 4);
            buffer_write(name_buf, buffer_string, "&name=" + name);
            network_send_raw(socket, name_buf, buffer_get_size(name_buf));
            buffer_delete(name_buf);

            create_chat_textbox("");
            naming_active = false;
            return_pressed = false;
            exit;
        }
    } else if (cancel_click || keyboard_check_pressed(vk_escape)) {
        global.chat_input_blocked = false;
        if (socket != noone) {
            network_destroy(socket);
            socket = noone;
        }
        if (ds_exists(Talkstr_list, ds_type_list)) {
            ds_list_destroy(Talkstr_list);
            Talkstr_list = noone;
        }
        room_goto(RoomCchoose);
        exit;
    }

    exit;
}

// ===== 右上角更多信息按钮 =====
if (mouse_check_button_pressed(mb_left)) {
    var more_rect = ui_chat_more_rect();
    if (point_in_rectangle(mouse_x, mouse_y, more_rect[0], more_rect[1], more_rect[2], more_rect[3])) {
        info_active = true;
        global.chat_input_blocked = true;
        chat_draft = instance_exists(textbox_1) ? textbox_return(textbox_1) : "";
        if (instance_exists(textbox_1)) {
            instance_destroy(textbox_1);
            textbox_1 = noone;
        }
        exit;
    }
}

// ===== 左上角返回按钮（返回房间列表）=====
if (mouse_check_button_pressed(mb_left)) {
    var back = ui_back_rect();
    if (point_in_rectangle(mouse_x, mouse_y, back[0], back[1], back[2], back[3])) {
        global.chat_input_blocked = false;
        if (socket != noone) {
            network_destroy(socket);
            socket = noone;
        }
        if (ds_exists(Talkstr_list, ds_type_list)) {
            ds_list_destroy(Talkstr_list);
            Talkstr_list = noone;
        }
        room_goto(RoomCchoose);
        exit;
    }
}

// ===== 发送按钮 =====
if (mouse_check_button_pressed(mb_left)) {
    var send_rect = ui_chat_send_rect();
    if (point_in_rectangle(mouse_x, mouse_y, send_rect[0], send_rect[1], send_rect[2], send_rect[3])) {
        send_chat_message();
        exit;
    }
}

// ===== Enter / Alt+S 发送 =====
if (keyboard_check_pressed(vk_enter) || (keyboard_check(vk_alt) && keyboard_check_pressed(ord("S")))) {
    send_chat_message();
}
