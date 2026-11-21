server_list = ds_list_create();
server_names = ds_list_create();
server_ip_map = ds_map_create();
server_port_map = ds_map_create();
server_player_counts = ds_map_create();  // 每个服务器的在线人数（键: IP）
broadcast_server = network_create_server_raw(network_socket_udp, 6511, 20);

// 主动停止 UDP 发现监听：先解除 id 关联，避免销毁后仍有排队的异步事件
stop_listening = function() {
    if (broadcast_server >= 0) {
        var socket_id = broadcast_server;
        broadcast_server = noone;
        network_destroy(socket_id);
    }
};

// 确保字体已就绪（SimHei 会在需要时按需加载）
ui_ensure_fonts();

// 兜底：加入房间前设置的昵称
if (!variable_global_exists("client_pending_name")) {
    global.client_pending_name = "";
}
if (!variable_global_exists("client_connect_port")) {
    global.client_connect_port = 6510;
}
if (!variable_global_exists("client_room_name")) {
    global.client_room_name = "聊天室";
}
if (!variable_global_exists("client_room_id")) {
    global.client_room_id = "";
}
if (!variable_global_exists("client_room_players")) {
    global.client_room_players = 0;
}
if (!variable_global_exists("chat_input_blocked")) {
    global.chat_input_blocked = false;
}

// ===== 房间列表布局 =====
list_x = 20;
list_y = 40;
list_width = 600;
list_height = 340;                 // 可视区域：40 ~ 380
list_padding = 16;
list_item_height = 56;             // 每个房间项高度
list_visible_rows = max(1, floor(list_height / list_item_height));  // 6 行
list_scroll_row = 0;               // 以“行”为单位滚动，整行滚动可避免文字溢出

// ===== 列表刷新 =====
refresh_stale_ms = 6000;           // 超过 6 秒没收到广播视为过期
auto_refresh_interval = 20000;     // 每 20 秒自动刷新
last_refresh_time = current_time;
refresh_flash_until = 0;

refresh_room_list = function(show_flash) {
    var now = current_time;
    var count = ds_list_size(server_list);

    // 1. 先移除近期没有广播的失效卡片
    for (var i = count - 1; i >= 0; i--) {
        var cur_key = server_list[| i];
        var has_seen = ds_map_exists(server_last_seen, cur_key);
        var seen = has_seen ? ds_map_find_value(server_last_seen, cur_key) : now;

        if (!has_seen || now - seen > refresh_stale_ms) {
            ds_list_delete(server_list, i);
            ds_list_delete(server_names, i);
            ds_map_delete(server_last_seen, cur_key);
            ds_map_delete(server_player_counts, cur_key);
            ds_map_delete(server_ip_map, cur_key);
            ds_map_delete(server_port_map, cur_key);
        }
    }

    // 2. 快照剩余有效卡片
    var valid_keys = [];
    var valid_names = [];
    var valid_counts = [];
    var valid_seen = [];
    var valid_ips = [];
    var valid_ports = [];
    var valid_total = ds_list_size(server_list);

    for (var j = 0; j < valid_total; j++) {
        var snap_key = server_list[| j];
        array_push(valid_keys, snap_key);
        array_push(valid_names, server_names[| j]);
        array_push(valid_counts, ds_map_exists(server_player_counts, snap_key) ? ds_map_find_value(server_player_counts, snap_key) : -1);
        array_push(valid_seen, ds_map_exists(server_last_seen, snap_key) ? ds_map_find_value(server_last_seen, snap_key) : now);
        array_push(valid_ips, ds_map_exists(server_ip_map, snap_key) ? ds_map_find_value(server_ip_map, snap_key) : "");
        array_push(valid_ports, ds_map_exists(server_port_map, snap_key) ? ds_map_find_value(server_port_map, snap_key) : 6510);
    }

    // 3. 清空数据，准备重新绘制卡片列表
    ds_list_clear(server_list);
    ds_list_clear(server_names);
    ds_map_clear(server_player_counts);
    ds_map_clear(server_last_seen);
    ds_map_clear(server_ip_map);
    ds_map_clear(server_port_map);

    // 4. 重新加入有效卡片
    for (var k = 0; k < array_length(valid_keys); k++) {
        var re_key = valid_keys[k];
        ds_list_add(server_list, re_key);
        ds_list_add(server_names, valid_names[k]);
        ds_map_add(server_player_counts, re_key, valid_counts[k]);
        ds_map_add(server_last_seen, re_key, valid_seen[k]);
        ds_map_add(server_ip_map, re_key, valid_ips[k]);
        ds_map_add(server_port_map, re_key, valid_ports[k]);
    }

    // 4.5 按拼音/字母排序后再绘制
    sort_room_list();

    // 5. 手动刷新回到顶部；自动刷新保持当前位置
    if (show_flash) {
        list_scroll_row = 0;
        refresh_flash_until = now + 1200;
    } else {
        var max_row = max(0, ds_list_size(server_list) - list_visible_rows);
        list_scroll_row = clamp(list_scroll_row, 0, max_row);
    }

    last_refresh_time = now;
};

sort_room_list = function() {
    var n = ds_list_size(server_list);
    if (n <= 1) return;

    var items = [];
    for (var a = 0; a < n; a++) {
        var key = server_list[| a];
        var nm = server_names[| a];
        array_push(items, {
            r_id: key,
            r_ip: ds_map_exists(server_ip_map, key) ? ds_map_find_value(server_ip_map, key) : "",
            r_port: ds_map_exists(server_port_map, key) ? ds_map_find_value(server_port_map, key) : 6510,
            r_name: nm,
            r_sort: pinyin_sort_key(nm),
            r_count: ds_map_exists(server_player_counts, key) ? ds_map_find_value(server_player_counts, key) : -1,
            r_seen: ds_map_exists(server_last_seen, key) ? ds_map_find_value(server_last_seen, key) : current_time
        });
    }

    // 按拼音/字母升序做插入排序（从上到下）
    for (var b = 1; b < n; b++) {
        var item = items[b];
        var j = b - 1;

        while (j >= 0) {
            var prev_item = items[j];
            var move = sort_key_less(item.r_sort, prev_item.r_sort);

            if (!move && item.r_sort == prev_item.r_sort) {
                move = sort_key_less(string_lower(item.r_name), string_lower(prev_item.r_name));
            }
            if (!move) break;

            items[j + 1] = items[j];
            j--;
        }
        items[j + 1] = item;
    }

    ds_list_clear(server_list);
    ds_list_clear(server_names);
    ds_map_clear(server_player_counts);
    ds_map_clear(server_last_seen);
    ds_map_clear(server_ip_map);
    ds_map_clear(server_port_map);

    for (var k = 0; k < n; k++) {
        var it = items[k];
        ds_list_add(server_list, it.r_id);
        ds_list_add(server_names, it.r_name);
        ds_map_add(server_player_counts, it.r_id, it.r_count);
        ds_map_add(server_last_seen, it.r_id, it.r_seen);
        ds_map_add(server_ip_map, it.r_id, it.r_ip);
        ds_map_add(server_port_map, it.r_id, it.r_port);
    }

    var max_row = max(0, ds_list_size(server_list) - list_visible_rows);
    list_scroll_row = clamp(list_scroll_row, 0, max_row);
};

// ===== 右侧连接按钮 =====
btn_width = 84;
btn_height = 34;
btn_margin = 14;                   // 按钮距列表右边缘
btn_radius = 6;

// ===== 加入房间前的昵称弹窗 =====
join_name_active = false;
join_name_text = "";
join_name_error = "";
join_name_target_ip = "";
join_name_target_port = 6510;
join_name_max_length = 15;

// ===== 手动连接 IP 弹窗（游戏内弹窗）=====
manual_ip_active = false;
manual_ip_text = "";
manual_ip_error = "";
manual_ip_max_length = 64;

// ===== 连接前连通性检查 =====
join_checking = false;
join_check_started = false;
join_check_socket = noone;
join_check_start = 0;
join_check_timeout = 3000;

start_join_check = function() {
    join_checking = true;
    join_check_start = current_time;

    join_check_socket = network_create_socket(network_socket_tcp);
    if (join_check_socket < 0) {
        fail_join_check("无法创建连接，请重试");
        return;
    }

    network_set_config(network_config_connect_timeout, 2000);

    var check_port = (client_connect_port > 0) ? client_connect_port : 6510;
    var result = network_connect_raw(join_check_socket, client_connect_server, check_port);
    if (result < 0) {
        fail_join_check("无法连接到该房间，请重试");
    } else {
        // network_connect_raw 是同步的：返回 >= 0 表示已经连通
        network_destroy(join_check_socket);
        join_check_socket = noone;
        join_checking = false;

        stop_listening();
        room_goto(RoomC);
    }
};

fail_join_check = function(message) {
    if (join_check_socket >= 0) {
        network_destroy(join_check_socket);
    }
    join_check_socket = noone;
    join_checking = false;
    join_name_active = true;
    join_name_error = message;
};

// ===== 预创建字体（避免每帧 font_add 造成内存泄漏） =====
// ===== 过期服务器清理 =====
server_last_seen = ds_map_create();  // 存储服务器最后出现时间
last_cleanup_time = current_time;    // 上次清理时间
cleanup_interval = 30000;            // 清理间隔：30 秒
server_timeout = 60000;              // 服务器超时时间：60 秒
