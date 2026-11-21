map = async_load;
type = ds_map_find_value(map, "type");
server = ds_map_find_value(map, "id");
var buf;

if(type == network_type_data) {
    buf = ds_map_find_value(map, "buffer");
    
    // 添加错误检查：空/无效缓冲区不读取
    if (!is_undefined(buf) && buffer_exists(buf)) {
        var _size = buffer_get_size(buf);
        if (_size <= 0) exit;
        if (buffer_peek(buf, _size - 1, buffer_u8) != 0) exit;

        getmes = buffer_read(buf, buffer_string);
        
        // 估算当前在线人数（服务端加入/离开通知）
        if (string_copy(getmes, 0, 6) == "&coly=") {
            if (string_pos("已加入", getmes) > 0) {
                online_count++;
            } else if (string_pos("已离开", getmes) > 0) {
                online_count = max(0, online_count - 1);
            }
        }

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
    // 已经由返回按钮 / 取消弹窗主动断开，避免重复提示
    if (socket == noone) exit;

    // 服务器断开连接
    if (socket != noone) {
        network_destroy(socket);
        socket = noone;
    }
    if (ds_exists(Talkstr_list, ds_type_list)) {
        ds_list_destroy(Talkstr_list);
        Talkstr_list = noone;
    }
    show_message("与服务器的连接已断开");
    room_goto(RoomCchoose);
}
