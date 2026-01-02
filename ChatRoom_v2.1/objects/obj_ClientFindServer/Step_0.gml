// 清理过期服务器（每30秒执行一次）
if (current_time - last_cleanup_time > cleanup_interval) {
    var server_count = ds_list_size(server_list);
    
    // 从后向前遍历（避免删除时索引问题）
    for (var i = server_count - 1; i >= 0; i--) {
        var ip = server_list[| i];
        
        if (ds_map_exists(server_last_seen, ip)) {
            var last_seen = ds_map_find_value(server_last_seen, ip);
            var time_since_seen = current_time - last_seen;
            
            // 如果超过60秒没有收到广播，移除该服务器
            if (time_since_seen > server_timeout) {
                // 移除服务器
                ds_list_delete(server_list, i);
                ds_list_delete(server_names, i);
                ds_map_delete(server_last_seen, ip);
                
            }
        } else {
            // 如果没有记录时间，也清理掉
            ds_list_delete(server_list, i);
            ds_list_delete(server_names, i);
        }
    }
    
    last_cleanup_time = current_time;
}