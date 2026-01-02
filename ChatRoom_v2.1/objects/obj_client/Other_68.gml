map = async_load;
type = ds_map_find_value(map, "type");
server = ds_map_find_value(map, "id");
var buf;

if(type == network_type_data) {
    buf = ds_map_find_value(map, "buffer");
    
    // 添加错误检查
    if (!is_undefined(buf)) {
        getmes = buffer_read(buf, buffer_string);
        
        // 检查Talkstr_list是否存在
        if (ds_exists(Talkstr_list, ds_type_list)) {
            if(string_copy(getmes, 0, 6) != "&sern=") {
                ds_list_add(Talkstr_list, getmes);
                if(ds_list_size(Talkstr_list) > 20) {
                    ds_list_delete(Talkstr_list, 0);
                }
            }
        } else {
            // 如果列表不存在，重新创建（安全措施）
            Talkstr_list = ds_list_create();
        }
    }
}

// 检查是否是断开连接的消息
if(type == network_type_disconnect) {
    // 服务器断开连接
    if (socket != noone) {
        network_destroy(socket);
        socket = noone;
    }
    show_message("与服务器的连接已断开");
    room_goto(RoomCchoose);
}