// ===== 房间命名弹窗 =====
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
            name_error = "名称不能为空";
        } else {
            servername = trimmed;
            name_error = "";

            // 每次创建房间生成 20 位随机标识，用于区分同名房间
            var id_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
            var id_len = string_length(id_chars);
            room_id = "";
            for (var n = 0; n < 20; n++) {
                room_id += string_char_at(id_chars, irandom(id_len - 1) + 1);
            }

            // 确认名称后才创建网络资源
            broadcast_buffer = buffer_create(256, buffer_fixed, 1);
            myself = network_create_server_raw(network_socket_tcp, 6510, 20);
            broadcast_socket = network_create_socket(network_socket_udp);

            socket_list = ds_list_create();
            name_list = ds_list_create();
            ip_list = ds_list_create();

            room_start_time = current_time;
            member_scroll_row = 0;

            server_started = true;
            naming_active = false;
            alarm_set(0, 20);
        }
    } else if (cancel_click || keyboard_check_pressed(vk_escape)) {
        // 取消：销毁常驻的服务器对象，避免它跟随进入主界面
        instance_destroy();
        room_goto(RoomMain);
        exit;
    }

    exit; // 弹窗期间不处理其它逻辑
}

// ESC键退出
if (keyboard_check_pressed(vk_escape)) {
    game_end();
}

// ===== 在线成员列表滚轮滚动 =====
var _content_y = 80;
var _content_height = room_height - 140;
var _rows_start_y = _content_y + 10 + 30;                 // 表头起始 y
var _data_start_y = _rows_start_y + 30;                   // 数据行起始 y
var _rows_end_y = _content_y + _content_height - 20;      // 数据区底部 y
var _row_spacing = 24;
var _visible_rows = max(1, floor((_rows_end_y - _data_start_y) / _row_spacing));
var _user_count = min(ds_list_size(ip_list), ds_list_size(name_list));
var _max_row = max(0, _user_count - _visible_rows);

// 仅当鼠标位于主内容区域时响应滚轮
if (point_in_rectangle(mouse_x, mouse_y, 10, _content_y,
                       room_width - 10, _content_y + _content_height)) {
    if (mouse_wheel_up())   member_scroll_row -= 2;   // 成员行较矮，一次滚 2 行
    if (mouse_wheel_down()) member_scroll_row += 2;
}

// 成员增减后限制滚动范围
member_scroll_row = clamp(member_scroll_row, 0, _max_row);
