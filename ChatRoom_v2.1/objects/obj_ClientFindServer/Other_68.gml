var map = async_load;
if(map[? "id"] == broadcast_server) {
    var ip = map[? "ip"];
    var buff = map[? "buffer"];
    var name = buffer_read(buff, buffer_string);
    var index = ds_list_find_index(server_list, ip);
    
    if(index < 0) {
        if(string_copy(name, 0, 6) == "&sern=") {
            var server_name = string_copy(name, 7, string_length(name) - 6);
            
            // 添加到服务器列表
            ds_list_add(server_list, ip);
            ds_list_add(server_names, server_name);
            
            // 记录最后活跃时间
            ds_map_add(server_last_seen, ip, current_time);
			
        }
    } else {
        // 更新服务器最后活跃时间
        if (ds_map_exists(server_last_seen, ip)) {
            ds_map_replace(server_last_seen, ip, current_time);
        }
    }
}