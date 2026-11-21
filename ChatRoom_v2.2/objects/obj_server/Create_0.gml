// ===== 房间命名弹窗状态 =====
// 名称确认后才创建网络资源，取消则直接返回主界面
servername = "";
room_id = "";
server_started = false;
naming_active = true;
name_text = "";
name_error = "";
name_max_length = 30;

// 确保字体已就绪（SimHei 会在需要时按需加载）
ui_ensure_fonts();

// 服务器资源在确认名称后创建（见 Step 事件）
broadcast_buffer = noone;
myself = noone;
broadcast_socket = noone;
socket_list = noone;
name_list = noone;
ip_list = noone;

sendmes = "";
getmes = "";

// 记录房间开始时间（用于计算运行时间）
room_start_time = current_time;

// 在线成员列表滚动位置（以“行”为单位）
member_scroll_row = 0;
