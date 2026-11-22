package com.nuoezin.chatroom.model;

public final class Member {
    public final String name;
    public final String address;
    public final boolean host;

    public Member(String name, String address, boolean host) {
        this.name = name == null ? "" : name;
        this.address = address == null ? "" : address;
        this.host = host;
    }
}
