
servername = get_string("你想给该聊天室取个什么名字？","");

broadcast_buffer = buffer_create(32,buffer_fixed,1);
myself = network_create_server_raw(network_socket_tcp,6510,20);

sendmes = "";
getmes = "";

socket_list = ds_list_create();
name_list = ds_list_create();
ip_list = ds_list_create();

// 记录房间开始时间（用于计算运行时间）
room_start_time = current_time;

alarm_set(0,20);