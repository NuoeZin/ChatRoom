package com.nuoezin.chatroom.model;

public final class RoomInfo {
    public final String name;
    public final String address;
    public final int port;
    public final int playerCount;
    public final String roomId;
    public final long lastSeen;

    public RoomInfo(String name, String address, int port, int playerCount,
                    String roomId, long lastSeen) {
        this.name = name == null || name.isEmpty() ? "未命名房间" : name;
        this.address = address == null ? "" : address;
        this.port = port;
        this.playerCount = Math.max(0, playerCount);
        this.roomId = roomId == null ? "" : roomId;
        this.lastSeen = lastSeen;
    }

    public String key() {
        return roomId.length() == 20 ? roomId : address + ":" + port;
    }
}
