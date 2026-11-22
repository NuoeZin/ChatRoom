package com.nuoezin.chatroom.model;

import java.util.Objects;

public final class ChatMessage {
    public enum Type {
        SYSTEM,
        OTHER,
        SELF
    }

    public final Type type;
    public final String sender;
    public final String text;
    public final long timestamp;

    public ChatMessage(Type type, String sender, String text, long timestamp) {
        this.type = type;
        this.sender = sender == null ? "" : sender;
        this.text = text == null ? "" : text;
        this.timestamp = timestamp;
    }

    public static ChatMessage system(String text) {
        return new ChatMessage(Type.SYSTEM, "", text, System.currentTimeMillis());
    }

    public static ChatMessage other(String sender, String text) {
        return new ChatMessage(Type.OTHER, sender, text, System.currentTimeMillis());
    }

    public static ChatMessage self(String sender, String text) {
        return new ChatMessage(Type.SELF, sender, text, System.currentTimeMillis());
    }

    public boolean samePayload(ChatMessage other) {
        return other != null
                && Objects.equals(sender, other.sender)
                && Objects.equals(text, other.text);
    }
}
