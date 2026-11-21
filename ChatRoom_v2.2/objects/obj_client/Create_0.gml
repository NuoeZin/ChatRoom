// 首先声明所有需要的变量
ui_ensure_fonts();

socket = noone;
Talkstr_list = noone;
textbox_1 = noone;
return_pressed = false;
chat_scroll = 0;
name = "";
sendmes = "";
getmes = "";

// 昵称设置弹窗状态
naming_active = false;
name_text = "";
name_error = "";
name_max_length = 15;

// 房间/聊天信息弹窗状态
info_active = false;
online_count = 0;
connect_time = current_time;
chat_draft = "";

if (!variable_global_exists("client_room_name")) global.client_room_name = "聊天室";
if (!variable_global_exists("client_room_id")) global.client_room_id = "";
if (!variable_global_exists("client_room_players")) global.client_room_players = 0;
if (!variable_global_exists("chat_input_blocked")) global.chat_input_blocked = false;
global.chat_input_blocked = false;
online_count = max(0, client_room_players);

// 统一创建/重建聊天输入框，并保持聚焦
create_chat_textbox = function(_text) {
    if (is_undefined(_text)) _text = "";
    if (instance_exists(textbox_1)) {
        instance_destroy(textbox_1);
    }
    textbox_1 = textbox_create(12, 356, 516, 26, _text, "输入消息，Enter 发送", 200, true, false);
    textbox_set_font(textbox_1, font_mc, make_color_rgb(235, 240, 250), 20, 1.5);
    with (textbox_1) {
        curt.fo = true;
        draw.dc = 30;
        draw.re = true;
        keyboard_string = "";
    }
};

// 发送消息，并在发送后重新聚焦输入框
send_chat_message = function() {
    if (!instance_exists(textbox_1)) return;
    var msg = textbox_return(textbox_1);
    if (msg == "") return;
    if (socket == noone) return;

    var payload = name + ":" + msg;
    var buf = buffer_create(10000, buffer_fixed, 4);
    buffer_write(buf, buffer_string, payload);
    network_send_raw(socket, buf, buffer_get_size(buf));
    buffer_delete(buf);

    create_chat_textbox("");
};

// 清理可能的残留资源
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

// 确保 client_connect_server 变量存在且有效
if (!is_string(client_connect_server) || client_connect_server == "") {
    show_message("服务器地址无效！");
    room_goto(RoomCchoose);
    exit;
}

var connect_port = 6510;
if (variable_global_exists("client_connect_port") && is_real(client_connect_port) && client_connect_port > 0) {
    connect_port = client_connect_port;
}
connect = network_connect_raw(socket, client_connect_server, connect_port);

if (connect < 0) {
    show_message("连接服务器失败！请检查服务器地址或网络连接。");
    room_goto(RoomCchoose);
} else {
    connect_time = current_time;
    Talkstr_list = ds_list_create();
    sendmes = "";
    getmes = "";
    return_pressed = false;

    // 从房间列表带入昵称：直接发送并进入聊天，跳过本房间的昵称弹窗
    var pending_name = "";
    if (variable_global_exists("client_pending_name") && is_string(global.client_pending_name)) {
        pending_name = string_trim(global.client_pending_name);
    }

    if (pending_name != "") {
        name = pending_name;
        global.client_pending_name = "";

        var name_buf;
        name_buf = buffer_create(10000, buffer_fixed, 4);
        buffer_write(name_buf, buffer_string, "&name=" + name);
        network_send_raw(socket, name_buf, buffer_get_size(name_buf));
        buffer_delete(name_buf);

        create_chat_textbox("");

        naming_active = false;
    } else {
        // 兜底：没有带入昵称时，仍在聊天界面弹出昵称设置
        naming_active = true;
        name_text = "";
        name_error = "";
    }
}
