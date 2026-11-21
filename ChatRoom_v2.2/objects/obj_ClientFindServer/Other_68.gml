var map = async_load;

// 只处理当前 UDP 发现套接字的数据事件；离开列表后不再处理
if (broadcast_server < 0) exit;
if (map[? "id"] != broadcast_server) exit;
if (map[? "type"] != network_type_data) exit;

var buff = map[? "buffer"];
if (!buffer_exists(buff)) exit;

var bsize = buffer_get_size(buff);
if (bsize <= 0) exit;

// 在真实缓冲区内查找 \0；找不到就忽略，绝不越界读取
var has_null = false;
for (var i = 0; i < bsize; i++) {
    if (buffer_peek(buff, i, buffer_u8) == 0) {
        has_null = true;
        break;
    }
}
if (!has_null) exit;

buffer_seek(buff, buffer_seek_start, 0);
var name = buffer_read(buff, buffer_string);
if (!is_string(name) || name == "") exit;
if (!string_starts_with(name, "&sern=")) exit;

var ip = map[? "ip"];
var payload = string_copy(name, 7, string_length(name) - 6);
var p1 = string_pos("|", payload);
var server_name = payload;
var player_count = -1;
var server_port = 6510;
var server_id = "";

if (p1 > 0) {
    server_name = string_copy(payload, 1, p1 - 1);
    var rest = string_copy(payload, p1 + 1, string_length(payload) - p1);
    var p2 = string_pos("|", rest);

    if (p2 > 0) {
        player_count = real(string_copy(rest, 1, p2 - 1));
        var rest2 = string_copy(rest, p2 + 1, string_length(rest) - p2);
        var p3 = string_pos("|", rest2);

        if (p3 > 0) {
            server_port = real(string_copy(rest2, 1, p3 - 1));
            server_id = string_copy(rest2, p3 + 1, string_length(rest2) - p3);
        } else {
            server_port = real(rest2);
        }
    } else {
        player_count = real(rest);
    }
}

if (server_port <= 0 || server_port > 65535) {
    server_port = 6510;
}
if (string_length(server_id) != 20) {
    server_id = "";
}

var key;
if (server_id != "") {
    key = server_id;
} else {
    key = ip + ":" + string_format(server_port, 1, 0);
}
var index = ds_list_find_index(server_list, key);

if (index < 0) {
    // 新服务器
    ds_list_add(server_list, key);
    ds_list_add(server_names, server_name);
    ds_map_add(server_ip_map, key, ip);
    ds_map_add(server_port_map, key, server_port);
    ds_map_add(server_player_counts, key, player_count);
    ds_map_add(server_last_seen, key, current_time);

    // 新房间加入后立即按拼音/字母排序
    sort_room_list();
} else {
    // 已存在的服务器：更新名称、人数和活跃时间
    ds_list_delete(server_names, index);
    ds_list_insert(server_names, index, server_name);

    if (ds_map_exists(server_ip_map, key)) {
        ds_map_replace(server_ip_map, key, ip);
    } else {
        ds_map_add(server_ip_map, key, ip);
    }

    if (ds_map_exists(server_port_map, key)) {
        ds_map_replace(server_port_map, key, server_port);
    } else {
        ds_map_add(server_port_map, key, server_port);
    }

    if (ds_map_exists(server_player_counts, key)) {
        ds_map_replace(server_player_counts, key, player_count);
    } else {
        ds_map_add(server_player_counts, key, player_count);
    }

    if (ds_map_exists(server_last_seen, key)) {
        ds_map_replace(server_last_seen, key, current_time);
    } else {
        ds_map_add(server_last_seen, key, current_time);
    }
}
