// 清理所有数据结构和网络资源
if (ds_exists(server_list, ds_type_list)) {
    ds_list_destroy(server_list);
}
if (ds_exists(server_names, ds_type_list)) {
    ds_list_destroy(server_names);
}
if (ds_exists(server_last_seen, ds_type_map)) {
    ds_map_destroy(server_last_seen);
}

// 直接调用 network_destroy，GameMaker 会处理无效的 socket
network_destroy(broadcast_server);