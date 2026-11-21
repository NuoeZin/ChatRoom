global.chat_input_blocked = false;

// 离开聊天室时清理网络连接、消息列表和输入框实例
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
