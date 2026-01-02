if (hover_create) {
    room_goto(RoomS);
} else if (hover_join) {
    room_goto(RoomCchoose);
}

// 重置按钮状态
hover_create = false;
hover_join = false;
button_pressed = false;