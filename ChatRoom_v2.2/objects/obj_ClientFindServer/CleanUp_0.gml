// 清理所有数据结构和网络资源
if (ds_exists(server_list, ds_type_list)) {
    ds_list_destroy(server_list);
}
if (ds_exists(server_names, ds_type_list)) {
    ds_list_destroy(server_names);
}
if (ds_exists(server_ip_map, ds_type_map)) {
    ds_map_destroy(server_ip_map);
}
if (ds_exists(server_port_map, ds_type_map)) {
    ds_map_destroy(server_port_map);
}
if (ds_exists(server_last_seen, ds_type_map)) {
    ds_map_destroy(server_last_seen);
}
if (ds_exists(server_player_counts, ds_type_map)) {
    ds_map_destroy(server_player_counts);
}

// 先解除 id 关联，再销毁套接字，避免销毁后仍有排队的异步事件访问缓冲区
if (broadcast_server >= 0) {
    var socket_id = broadcast_server;
    broadcast_server = noone;
    network_destroy(socket_id);
}

// 清理连接前检测使用的临时套接字
if (join_check_socket >= 0) {
    network_destroy(join_check_socket);
    join_check_socket = noone;
}
