// ===== 连接前连通性检查 =====
if (join_checking) {
    // 先让 Draw 显示一帧“正在连接”遮罩，再执行同步连接检测
    if (!join_check_started) {
        join_check_started = true;
        start_join_check();
        exit;
    }

    if (current_time - join_check_start > join_check_timeout) {
        fail_join_check("连接超时，无法加入该房间");
    }
    exit;
}

// ===== 手动连接 IP 弹窗 =====
if (manual_ip_active) {
    var old_ip_text = manual_ip_text;
    manual_ip_text = ui_name_dialog_update_text(manual_ip_text, manual_ip_max_length);
    if (manual_ip_text != old_ip_text) {
        manual_ip_error = "";
    }

    var ip_rects = ui_name_dialog_rects();
    var ip_ok = mouse_check_button_pressed(mb_left) &&
        point_in_rectangle(mouse_x, mouse_y, ip_rects.ok[0], ip_rects.ok[1], ip_rects.ok[2], ip_rects.ok[3]);
    var ip_cancel = mouse_check_button_pressed(mb_left) &&
        point_in_rectangle(mouse_x, mouse_y, ip_rects.cancel[0], ip_rects.cancel[1], ip_rects.cancel[2], ip_rects.cancel[3]);

    if (ip_ok || keyboard_check_pressed(vk_enter)) {
        var input = string_trim(manual_ip_text);

        if (input == "") {
            manual_ip_error = "IP 不能为空";
        } else {
            var host = input;
            var port = 6510;
            var valid = true;
            var colon = string_pos(":", input);

            if (colon > 0) {
                var pstr = string_copy(input, colon + 1, string_length(input) - colon);
                var parsed = real(pstr);

                if (parsed <= 0 || parsed > 65535) {
                    valid = false;
                    manual_ip_error = "端口无效（1-65535）";
                } else {
                    port = parsed;
                    host = string_trim(string_copy(input, 1, colon - 1));
                }
            }

            if (valid) {
                if (host == "") {
                    manual_ip_error = "IP 不能为空";
                } else {
                    join_name_target_ip = host;
                    join_name_target_port = port;
                    client_room_name = "手动连接";
                    client_room_id = host + ":" + string_format(port, 1, 0);
                    client_room_players = 0;
                    manual_ip_active = false;
                    manual_ip_text = "";
                    manual_ip_error = "";

                    // 接着进入昵称弹窗
                    join_name_active = true;
                    join_name_text = "";
                    join_name_error = "";
                }
            }
        }
    } else if (ip_cancel || keyboard_check_pressed(vk_escape)) {
        manual_ip_active = false;
        manual_ip_text = "";
        manual_ip_error = "";
    }

    exit;
}

// ===== 加入房间前的昵称弹窗 =====
if (join_name_active) {
    join_name_text = ui_name_dialog_update_text(join_name_text, join_name_max_length);

    var rects = ui_name_dialog_rects();
    var ok_click = mouse_check_button_pressed(mb_left) &&
        point_in_rectangle(mouse_x, mouse_y, rects.ok[0], rects.ok[1], rects.ok[2], rects.ok[3]);
    var cancel_click = mouse_check_button_pressed(mb_left) &&
        point_in_rectangle(mouse_x, mouse_y, rects.cancel[0], rects.cancel[1], rects.cancel[2], rects.cancel[3]);

    if (ok_click || keyboard_check_pressed(vk_enter)) {
        var trimmed = string_trim(join_name_text);

        if (trimmed == "") {
            join_name_error = "昵称不能为空";
        } else {
            client_pending_name = trimmed;
            client_connect_server = join_name_target_ip;
            client_connect_port = join_name_target_port;
            join_name_active = false;
            join_name_error = "";
            join_checking = true;
            join_check_started = false;
            exit;
        }
    } else if (cancel_click || keyboard_check_pressed(vk_escape)) {
        // 取消：关闭弹窗，留在房间列表
        join_name_active = false;
        join_name_text = "";
        join_name_error = "";
    }

    exit;
}

// ===== 清理过期服务器（每 30 秒执行一次）=====
if (current_time - last_cleanup_time > cleanup_interval) {
    var cleanup_count = ds_list_size(server_list);

    // 从后向前遍历（避免删除时索引问题）
    for (var i = cleanup_count - 1; i >= 0; i--) {
        var key = server_list[| i];

        if (ds_map_exists(server_last_seen, key)) {
            var last_seen = ds_map_find_value(server_last_seen, key);

            // 超过 60 秒没有收到广播，移除该服务器
            if (current_time - last_seen > server_timeout) {
                ds_list_delete(server_list, i);
                ds_list_delete(server_names, i);
                ds_map_delete(server_last_seen, key);
                ds_map_delete(server_player_counts, key);
                ds_map_delete(server_ip_map, key);
                ds_map_delete(server_port_map, key);
            }
        } else {
            // 没有记录时间的条目也清理掉
            ds_list_delete(server_list, i);
            ds_list_delete(server_names, i);
            ds_map_delete(server_player_counts, key);
            ds_map_delete(server_ip_map, key);
            ds_map_delete(server_port_map, key);
        }
    }

    last_cleanup_time = current_time;
}

// ===== 每 20 秒自动刷新一次列表 =====
if (current_time - last_refresh_time >= auto_refresh_interval) {
    // 重新开始列表房间，彻底清理失效卡片与旧监听
    room_restart();
    exit;
}

// ===== 鼠标滚轮滚动房间列表（仅鼠标位于列表区域时生效）=====
var server_count = ds_list_size(server_list);
var max_row = max(0, server_count - list_visible_rows);

if (point_in_rectangle(mouse_x, mouse_y, list_x, list_y,
                       list_x + list_width, list_y + list_height)) {
    if (mouse_wheel_up())   list_scroll_row -= 1;
    if (mouse_wheel_down()) list_scroll_row += 1;
}

// 列表项增减后限制滚动范围
list_scroll_row = clamp(list_scroll_row, 0, max_row);
