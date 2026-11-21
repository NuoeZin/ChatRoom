randomize();

globalvar font1;
globalvar font_mc;

// Minecraft 字体同时覆盖中文与英文，先加载它；
// SimHei 只在遇到其他语言字符时再懒加载，避免每次启动都扫描近 3 万个字形。
// 0x9FFF 以上的字形不会被混合字体规则选中，裁掉可明显缩短启动时间。
font_mc = add_font_r("Minecraft.ttf", 12, false, 0x9FFF);
global.font_cn = -2; // -2：尚未尝试加载 SimHei；-1：加载失败；>=0：已加载
font1 = font_mc;

// 兼容旧版本事件中可能残留的字体变量名，避免出现
// “Variable obj_main.font_small not set before reading it.”
font_small = font_mc;
font_title = font_mc;
font_mc_title = font_mc;
font_mc_small = font_mc;
font_mc_large = font_mc;
font_item_name = font_mc;
font_item_info = font_mc;
font_item_title = font_mc;
font_item_small = font_mc;

globalvar client_connect_server;
globalvar client_connect_port;
client_connect_port = 6510;
globalvar client_pending_name;
client_pending_name = "";

globalvar client_room_name;
client_room_name = "聊天室";
globalvar client_room_id;
client_room_id = "";
globalvar client_room_players;
client_room_players = 0;
globalvar chat_input_blocked;
chat_input_blocked = false;

// UI状态变量
hover_create = false;
hover_join = false;
button_pressed = false;

// 预计算所有静态值
// 背景缩放计算（预计算，避免每帧重复计算）
bg_width = sprite_get_width(spr_background);
bg_height = sprite_get_height(spr_background);
scale_x = 640 / bg_width;
scale_y = 400 / bg_height;

// 按钮属性（预计算所有位置，避免每帧计算）
button_width = 160;
button_height = 45;
button_y = 280;
button_gap = 50;
button1_x = (640 - (button_width * 2 + button_gap)) / 2;
button2_x = button1_x + button_width + button_gap;

// 预计算按钮边界用于碰撞检测
button1_left = button1_x;
button1_right = button1_x + button_width;
button1_top = button_y;
button1_bottom = button_y + button_height;

button2_left = button2_x;
button2_right = button2_x + button_width;
button2_top = button_y;
button2_bottom = button_y + button_height;

// 颜色定义 - 只使用 RGB 颜色
color_button_normal = make_colour_rgb(70, 130, 180);      // 钢蓝色
color_button_hover = make_colour_rgb(120, 180, 230);      // 更浅的悬停色（变淡效果）
color_button_pressed = make_colour_rgb(50, 100, 150);     // 深钢蓝色
color_button_border = make_colour_rgb(40, 80, 120);       // 边框颜色
color_button_text = make_colour_rgb(240, 248, 255);       // 爱丽丝蓝（文字颜色）

// 其他颜色
color_title = make_colour_rgb(64, 64, 64);               // 标题深灰色
color_text = make_colour_rgb(220, 220, 220);             // 正文浅灰色
color_version = make_colour_rgb(150, 150, 150);          // 版本信息灰色

// 透明度设置（简化）——主菜单两个大按钮保持完全不透明
button_alpha_normal = 1.0;
button_alpha_hover = 1.0;
button_alpha_pressed = 1.0;
text_bg_alpha = 0.6;            // 文字背景透明度（降低以减少绘制负载）

// 按钮圆角半径
button_radius = 8;

// 背景检查
if (!sprite_exists(spr_background)) {
    show_debug_message("警告：背景精灵 spr_background 不存在！");
}

// 性能计数器（用于减少某些计算的频率）
performance_counter = 0;

// ===== 关于对话框 / 更多信息 =====
more_active = false;
more_copied_until = 0;
more_url = "https://github.com/NuoeZin/ChatRoom";
more_img = -1;
about_img_loaded = false;
