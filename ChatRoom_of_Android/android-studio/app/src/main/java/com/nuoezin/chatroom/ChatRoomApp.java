package com.nuoezin.chatroom;

import android.app.Application;

import com.nuoezin.chatroom.net.RoomHost;

public final class ChatRoomApp extends Application {
    private RoomHost roomHost;

    public synchronized RoomHost getRoomHost() {
        return roomHost;
    }

    public synchronized void setRoomHost(RoomHost host) {
        if (roomHost != null && roomHost != host) {
            roomHost.close();
        }
        roomHost = host;
    }

    public synchronized void closeRoomHost() {
        if (roomHost != null) {
            roomHost.close();
            roomHost = null;
        }
    }
}
