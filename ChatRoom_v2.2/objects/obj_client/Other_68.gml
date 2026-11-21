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

        if (recv_buffer == noone || !buffer_exists(recv_buffer)) {
            recv_buffer = buffer_create(20000, buffer_fixed, 1);
            recv_temp = buffer_create(20000, buffer_fixed, 1);
            recv_start = 0;
            recv_end = 0;
        }

        var required = recv_end + _size;
        if (required > buffer_get_size(recv_buffer)) {
            var new_size = buffer_get_size(recv_buffer);
            while (new_size < required) new_size *= 2;
            buffer_resize(recv_buffer, new_size);
            buffer_resize(recv_temp, new_size);
        }

        buffer_copy(buf, 0, _size, recv_buffer, recv_end);
        recv_end += _size;

        // TCP 是字节流：一次事件可能包含半条、一条或多条消息
        while (recv_start < recv_end) {
            var nul_at = -1;
            for (var scan = recv_start; scan < recv_end; scan++) {
                if (buffer_peek(recv_buffer, scan, buffer_u8) == 0) {
                    nul_at = scan;
                    break;
                }
            }

            if (nul_at < 0) break;
            if (nul_at == recv_start) {
                recv_start++;
                continue;
            }

            buffer_seek(recv_buffer, buffer_seek_start, recv_start);
            getmes = buffer_read(recv_buffer, buffer_string);
            recv_start = nul_at + 1;
            process_server_message(getmes);

            // 跳过定长帧尾部的 NUL 填充
            while (recv_start < recv_end &&
                   buffer_peek(recv_buffer, recv_start, buffer_u8) == 0) {
                recv_start++;
            }
        }

        // 把尚未组成完整消息的尾部移回缓冲区开头
        var remaining = recv_end - recv_start;
        if (remaining > 0 && recv_start > 0) {
            buffer_copy(recv_buffer, recv_start, remaining, recv_temp, 0);
            buffer_copy(recv_temp, 0, remaining, recv_buffer, 0);
        }
        recv_start = 0;
        recv_end = remaining;
    }
}

// 检查是否是断开连接的消息
if(type == network_type_disconnect) {
    // 已经由返回按钮 / 取消弹窗主动断开，避免重复提示
    if (socket == noone) exit;

    server_alive = false;

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
