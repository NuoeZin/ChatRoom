// 首先声明所有需要的变量
socket = noone;
Talkstr_list = noone;
textbox_1 = noone;
return_pressed = false;
chat_scroll = 0;
name = "";  // 添加name变量的初始化
sendmes = ""; // 添加sendmes变量的初始化
getmes = "";  // 添加getmes变量的初始化

// 然后清理可能的残留资源
if (socket != noone) {
    network_destroy(socket);
    socket = noone;
}

if (ds_exists(Talkstr_list, ds_type_list)) {
    ds_list_destroy(Talkstr_list);
    Talkstr_list = noone;
}

if (instance_exists(textbox_1)) {
    instance_destroy(textbox_1);
    textbox_1 = noone;
}

// 重置连接参数
socket = network_create_socket(network_socket_tcp);
network_set_config(network_config_connect_timeout, 10000);

// 确保client_connect_server变量存在且有效
// 修正：使用更可靠的检查方式
if (!is_string(client_connect_server) || client_connect_server == "") {
    show_message("服务器地址无效！");
    room_goto(RoomCchoose);
    exit;
}

connect = network_connect_raw(socket, client_connect_server, 6510);

if(connect < 0) {
    show_message("连接服务器失败！请检查服务器地址或网络连接。");
    room_goto(RoomCchoose);
} else {
    // 确保name不为空
    var temp_name = "";
    while(temp_name == "") {
        temp_name = get_string("你将要使用的名称是？", "");
    }
    name = temp_name;  // 赋值给实例变量
    
    sendmes = "";
    getmes = "";
    
    var buf;
    buf = buffer_create(10000, buffer_fixed, 4);
    buffer_write(buf, buffer_string, "&name=" + name);
    network_send_raw(socket, buf, buffer_get_size(buf));
    buffer_delete(buf);
    
    // 重新创建列表
    Talkstr_list = ds_list_create();
    
    // 创建文本框
    textbox_1 = textbox_create(0, 360, 640, 20, "", "按下Enter 或 Alt+S 以发送消息", 120, true, false);
    textbox_set_font(textbox_1, font1, c_white, 18, 1.5);
    
    // 重置返回标记
    return_pressed = false;
}
