package com.nuoezin.chatroom.net;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

public final class Protocol {
    public static final int FRAME_SIZE = 10000;
    public static final int DEFAULT_PORT = 6510;
    public static final int BROADCAST_PORT = 6511;

    private Protocol() {
    }

    public static byte[] frame(String text, int size) {
        byte[] raw = text.getBytes(StandardCharsets.UTF_8);
        int length = Math.min(Math.max(1, size), FRAME_SIZE);
        byte[] result = new byte[length];
        int copy = Math.min(raw.length, length - 1);
        System.arraycopy(raw, 0, result, 0, copy);
        return result;
    }

    public static byte[] smallFrame(String text) {
        byte[] raw = text.getBytes(StandardCharsets.UTF_8);
        byte[] result = new byte[Math.min(raw.length, FRAME_SIZE - 1) + 1];
        System.arraycopy(raw, 0, result, 0, result.length - 1);
        return result;
    }

    public static void write(OutputStream stream, String text, boolean fixedFrame)
            throws IOException {
        synchronized (stream) {
            stream.write(fixedFrame ? frame(text, FRAME_SIZE) : smallFrame(text));
            stream.flush();
        }
    }

    public static String sanitizeName(String name) {
        String value = name == null ? "" : name.trim().replace('\n', ' ').replace('\r', ' ');
        if (value.length() > 15) {
            return value.substring(0, 12) + "...";
        }
        return value;
    }

    public static String roomId() {
        String chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        StringBuilder id = new StringBuilder(20);
        java.util.Random random = new java.util.Random();
        for (int i = 0; i < 20; i++) {
            id.append(chars.charAt(random.nextInt(chars.length())));
        }
        return id.toString();
    }

    public static final class MessageStream {
        private final ByteArrayOutputStream pending = new ByteArrayOutputStream();

        public java.util.List<String> feed(byte[] data, int length) {
            pending.write(data, 0, length);
            byte[] bytes = pending.toByteArray();
            int consumed = 0;
            java.util.List<String> messages = new java.util.ArrayList<>();

            for (int i = 0; i < bytes.length; i++) {
                if (bytes[i] != 0) {
                    continue;
                }
                if (i > consumed) {
                    messages.add(new String(bytes, consumed, i - consumed, StandardCharsets.UTF_8));
                }
                consumed = i + 1;
            }

            while (consumed < bytes.length && bytes[consumed] == 0) {
                consumed++;
            }

            pending.reset();
            if (consumed < bytes.length) {
                pending.write(bytes, consumed, bytes.length - consumed);
            }
            return messages;
        }
    }
}
