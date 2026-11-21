if (!server_started) exit;

var map = async_load;
var type = ds_map_find_value(map,"type");
var buf;
if(type == network_type_connect) {
	client = ds_map_find_value(map,"socket");//client指服务端接受的客户端id
	ip = ds_map_find_value(map,"ip");
	ds_list_add(socket_list,client);
	ds_list_add(ip_list,ip);
	// 与 socket_list 保持同索引对齐：未命名连接先占位
	ds_list_add(name_list,"");
	// 有新玩家加入，立即触发广播让局域网客户端刷新房间人数
	alarm_set(0, 1);
}

if(type == network_type_data) {
	// buffer_create(10000,buffer_fixed,4);
	buf = ds_map_find_value(map,"buffer");
	if (!buffer_exists(buf)) exit;

	var _buf_size = buffer_get_size(buf);
	if (_buf_size <= 0) exit;
	if (buffer_peek(buf, _buf_size - 1, buffer_u8) != 0) exit;

	getmes = buffer_read(buf,buffer_string);
	var send_this = true;
	var send_count = false;
	// network_type_data 使用 "id"；connect/disconnect 才使用 "socket"
	var csock = ds_map_find_value(map,"id");

	if (getmes == "") {
		// 空帧只可能是协议填充，不能广播成空聊天行
		send_this = false;
	} else if(string_starts_with(getmes, "&ping=")) {
		// 只向发送心跳的客户端回复，不能让 &ping= 进入公共聊天
		var pong = "&pong=" + string_copy(getmes, 7, string_length(getmes) - 6);
		var pong_size = string_byte_length(pong) + 1;
		var pong_buf = buffer_create(pong_size, buffer_fixed, 1);
		buffer_write(pong_buf, buffer_string, pong);
		network_send_raw(csock, pong_buf, pong_size);
		buffer_delete(pong_buf);
		send_this = false;
	} else if(string_starts_with(getmes, "&name=")) {
		// 昵称去掉首尾空白；空昵称直接忽略，不加入成员列表也不广播
		var gotname = string_trim(string_copy(getmes, 7, string_length(getmes) - 6));
		var idx = ds_list_find_index(socket_list, csock);

		if (gotname == "" || idx < 0 || name_list[| idx] != "") {
			// 空昵称 / 找不到连接 / 该连接已注册过昵称
			send_this = false;
		} else {
			// 用户名长度限制：如果超过15个字符，截断为12个字符
			if (string_length(gotname) > 15) {
				gotname = string_copy(gotname, 1, 12) + "...";
			}

			// 替换该连接在 name_list 中的占位，保持三个列表索引一致
			ds_list_delete(name_list, idx);
			ds_list_insert(name_list, idx, gotname);
			sendmes = "&coly=" + gotname + "已加入";
			send_count = true;
		}
	} else {
		sendmes = getmes;
	}

	if (send_this) {
		for(var i = 0; i < ds_list_size(socket_list); i++) {
			buf = buffer_create(10000,buffer_fixed,4);
			buffer_write(buf,buffer_string,sendmes);
			network_send_raw(socket_list[| i],buf,buffer_get_size(buf));
			buffer_delete(buf);
		}
	}

	if (send_count) {
		var count_text = "&count=" + string(ds_list_size(socket_list));
		var count_size = string_byte_length(count_text) + 1;
		var count_buf = buffer_create(count_size, buffer_fixed, 1);
		buffer_write(count_buf, buffer_string, count_text);
		network_send_raw(csock, count_buf, count_size);
		buffer_delete(count_buf);
	}
}

if(type == network_type_disconnect) {
	var index = ds_list_find_index(socket_list,ds_map_find_value(map,"socket"));
	if (index >= 0) {
		var exitname = name_list[| index];
		if (exitname != "") {
			sendmes = "&coly=" + exitname + "已离开";
			for(var j = 0; j < ds_list_size(socket_list); j++) {
				buf = buffer_create(10000,buffer_fixed,4);
				buffer_write(buf,buffer_string,sendmes);
				network_send_raw(socket_list[| j],buf,buffer_get_size(buf));
				buffer_delete(buf);
			}
		}
		ds_list_delete(socket_list,index);
		ds_list_delete(name_list,index);
		ds_list_delete(ip_list,index);
	}
	// 有玩家离开，立即触发广播让局域网客户端刷新房间人数
	alarm_set(0, 1);
}
