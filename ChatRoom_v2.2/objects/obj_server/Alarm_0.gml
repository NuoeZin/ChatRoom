if (!server_started) exit;

// 构建广播数据：格式 &sern=<服务器名称>|<在线人数>|<TCP端口>|<房间ID>
var player_count = ds_list_size(socket_list);
var broadcast_data = "&sern=" + servername + "|" + string(player_count) + "|6510|" + room_id;

buffer_seek(broadcast_buffer, buffer_seek_start, 0);
buffer_write(broadcast_buffer, buffer_string, broadcast_data);

// 使用专用UDP套接字发送广播（原来使用TCP套接字myself，导致广播无法发出）
network_send_broadcast(broadcast_socket, 6511, broadcast_buffer, buffer_tell(broadcast_buffer));
alarm_set(0, 60);
