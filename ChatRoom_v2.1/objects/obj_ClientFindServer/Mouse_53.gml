// 检查是否点击了手动连接区域（顶部标题栏）
if(mouse_y < 35) {
    var conip = get_string("输入要联机的聊天室服务器IP地址:", "");
    if(conip != "") {
        client_connect_server = conip;
        room_goto(RoomC);
    }
} 
// 检查是否点击了服务器列表项
else if(mouse_y >= list_start_y) {
    // 计算点击的是第几个服务器
    var item_index = floor((mouse_y - list_start_y) / list_item_height);
    var server_count = ds_list_size(server_list);
    
    // 确保索引有效
    if (item_index >= 0 && item_index < server_count) {
        client_connect_server = server_list[| item_index];
        var server_name = server_names[| item_index];
        
        // 使用 show_message 替代 get_integer（get_integer需要3个参数）
        var message = "是否连接到服务器？\n\n服务器名称: " + server_name + 
                     "\nIP地址: " + client_connect_server + 
                     "\n\n确定连接吗？";
        
        show_message(message);
        room_goto(RoomC);
        
    }
}