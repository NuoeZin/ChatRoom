// 昵称弹窗打开时，底层按钮不响应（弹窗点击由 Step 事件处理）
if (join_name_active || manual_ip_active || join_checking) exit;

// 左上角返回按钮：返回主界面
var back = ui_back_rect();
if (point_in_rectangle(mouse_x, mouse_y, back[0], back[1], back[2], back[3])) {
    stop_listening();
    room_goto(RoomMain);
}
// 返回按钮右侧：刷新房间列表
else if (point_in_rectangle(mouse_x, mouse_y, 42, 4, 68, 30)) {
    // 重新绘制列表房间：清空并重建房间列表实例
    room_restart();
}
// 右上角手动连接按钮
else if (point_in_rectangle(mouse_x, mouse_y, 528, 5, 632, 30)) {
    // 使用游戏内弹窗输入 IP/端口
    manual_ip_active = true;
    manual_ip_text = "";
    manual_ip_error = "";
}
// 列表区域：只有点击右侧「连接」按钮才弹出昵称弹窗
else if (point_in_rectangle(mouse_x, mouse_y, list_x, list_y,
                            list_x + list_width, list_y + list_height)) {
    var view_row = floor((mouse_y - list_y) / list_item_height);
    var item_index = list_scroll_row + view_row;
    var server_count = ds_list_size(server_list);

    if (view_row >= 0 && view_row < list_visible_rows &&
        item_index >= 0 && item_index < server_count) {

        var item_y = list_y + view_row * list_item_height;
        var btn_x = list_x + list_width - btn_width - btn_margin;
        var btn_y = item_y + (list_item_height - btn_height) * 0.5;

        if (point_in_rectangle(mouse_x, mouse_y,
                               btn_x, btn_y, btn_x + btn_width, btn_y + btn_height)) {
            var key = server_list[| item_index];
            var last_seen = ds_map_exists(server_last_seen, key) ? ds_map_find_value(server_last_seen, key) : 0;

            // 卡片已失效：拒绝连接，避免进入已关闭的房间
            if (current_time - last_seen > 3000) {
                show_message("该房间已经关闭或失去响应，请点击刷新按钮后重试。");
            } else {
                join_name_target_ip = ds_map_exists(server_ip_map, key) ? ds_map_find_value(server_ip_map, key) : key;
                join_name_target_port = ds_map_exists(server_port_map, key) ? ds_map_find_value(server_port_map, key) : 6510;
                client_room_name = server_names[| item_index];
                client_room_id = key;
                client_room_players = ds_map_exists(server_player_counts, key) ? ds_map_find_value(server_player_counts, key) : 0;
                join_name_active = true;
                join_name_text = "";
                join_name_error = "";
            }
        }
    }
}
