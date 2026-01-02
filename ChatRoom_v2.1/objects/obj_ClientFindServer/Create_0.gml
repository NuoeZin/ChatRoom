server_list = ds_list_create();
server_names = ds_list_create();
broadcast_server = network_create_server_raw(network_socket_udp,6511,20);

// 初始化显示参数
list_item_height = 60;       // 每个服务器项的高度
list_start_y = 40;           // 列表开始位置
list_padding = 15;           // 内边距

// 用于清理过期服务器的变量
server_last_seen = ds_map_create();  // 存储服务器最后出现时间
last_cleanup_time = current_time;    // 上次清理时间
cleanup_interval = 30000;            // 清理间隔：30秒
server_timeout = 60000;              // 服务器超时时间：60秒