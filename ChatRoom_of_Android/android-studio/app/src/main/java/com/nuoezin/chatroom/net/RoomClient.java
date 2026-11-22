package com.nuoezin.chatroom.net;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;

import com.nuoezin.chatroom.model.ChatMessage;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public final class RoomClient implements AutoCloseable {
    public interface Listener {
        void onConnected(int initialPlayers);

        void onCountChanged(int online);

        void onMessage(ChatMessage message);

        void onDisconnected(String reason);
    }

    private final String host;
    private final int port;
    private final String nickname;
    private final String roomName;
    private final String roomId;
    private final int initialPlayers;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ConcurrentLinkedQueue<String> pendingEchoes = new ConcurrentLinkedQueue<>();
    private final ScheduledExecutorService heartbeat =
            Executors.newSingleThreadScheduledExecutor(r -> {
                Thread thread = new Thread(r, "chatroom-heartbeat");
                thread.setDaemon(true);
                return thread;
            });
    private final java.util.concurrent.ExecutorService sender =
            Executors.newSingleThreadExecutor(r -> {
                Thread thread = new Thread(r, "chatroom-sender");
                thread.setDaemon(true);
                return thread;
            });
    private volatile boolean running;
    private volatile boolean connected;
    private volatile Socket socket;
    private volatile OutputStream output;
    private volatile long lastResponse;
    private volatile Listener listener;
    private volatile int online = 1;

    public RoomClient(String host, int port, String nickname, String roomName,
                      String roomId, int initialPlayers, Listener listener) {
        this.host = host;
        this.port = port;
        this.nickname = Protocol.sanitizeName(nickname);
        this.roomName = roomName;
        this.roomId = roomId;
        this.initialPlayers = Math.max(0, initialPlayers);
        this.online = Math.max(1, initialPlayers);
        this.listener = listener;
    }

    public void start() {
        if (running) {
            return;
        }
        running = true;
        Thread connector = new Thread(this::connectAndRead, "chatroom-client");
        connector.setDaemon(true);
        connector.start();
    }

    private void connectAndRead() {
        try {
            Socket value = new Socket();
            value.connect(new InetSocketAddress(host, port), 4000);
            value.setTcpNoDelay(true);
            socket = value;
            output = value.getOutputStream();
            lastResponse = SystemClock.elapsedRealtime();
            connected = true;
            Protocol.write(output, "&name=" + nickname, false);
            postConnected();
            startHeartbeat();

            Protocol.MessageStream stream = new Protocol.MessageStream();
            byte[] buffer = new byte[8192];
            try (InputStream input = value.getInputStream()) {
                int read;
                while (running && (read = input.read(buffer)) >= 0) {
                    lastResponse = SystemClock.elapsedRealtime();
                    for (String message : stream.feed(buffer, read)) {
                        process(message);
                    }
                }
            }
            if (running) {
                postDisconnected("与服务器的连接已断开");
            }
        } catch (IOException error) {
            if (running) {
                postDisconnected("无法连接到服务器，请返回后重试");
            }
        } finally {
            connected = false;
            closeSocket();
        }
    }

    private void startHeartbeat() {
        heartbeat.scheduleAtFixedRate(() -> {
            if (!running) {
                return;
            }
            if (SystemClock.elapsedRealtime() - lastResponse > 9000) {
                postDisconnected("服务器无响应");
                close();
                return;
            }
            try {
                sendRaw("&ping=" + SystemClock.elapsedRealtime());
            } catch (IOException ignored) {
                postDisconnected("与服务器的连接已断开");
                close();
            }
        }, 3, 3, TimeUnit.SECONDS);
    }

    private void process(String message) {
        if (message == null || message.isEmpty() || message.startsWith("&pong=")) {
            return;
        }
        if (message.startsWith("&sern=")) {
            return;
        }
        if (message.startsWith("&count=")) {
            try {
                online = Math.max(1, Integer.parseInt(message.substring(7).trim()));
                postCount();
            } catch (NumberFormatException ignored) {
            }
            return;
        }
        if (message.startsWith("&coly=")) {
            postMessage(ChatMessage.system(message.substring(6)));
            return;
        }

        String match = pendingEchoes.peek();
        if (match != null && match.equals(message)) {
            pendingEchoes.poll();
            return;
        }

        int colon = message.indexOf(':');
        if (colon > 0) {
            String sender = message.substring(0, colon);
            String text = message.substring(colon + 1);
            if (sender.equals(nickname)) {
                postMessage(ChatMessage.self(sender, text));
            } else {
                postMessage(ChatMessage.other(sender, text));
            }
        } else if (!message.startsWith("&")) {
            postMessage(ChatMessage.other("访客", message));
        }
    }

    public boolean sendMessage(String text) {
        String value = text == null ? "" : text.trim();
        if (value.isEmpty() || !connected) {
            return false;
        }
        String payload = nickname + ":" + value;
        pendingEchoes.add(payload);
        sender.execute(() -> {
            try {
                sendRaw(payload);
                postMessage(ChatMessage.self(nickname, value));
            } catch (IOException error) {
                pendingEchoes.remove(payload);
                postDisconnected("与服务器的连接已断开");
                close();
            }
        });
        return true;
    }

    private void sendRaw(String text) throws IOException {
        OutputStream stream = output;
        if (stream == null || !connected) {
            throw new IOException("Not connected");
        }
        Protocol.write(stream, text, false);
    }

    private void postConnected() {
        Listener target = listener;
        if (target == null) {
            return;
        }
        int players = initialPlayers;
        mainHandler.post(() -> target.onConnected(players));
    }

    private void postCount() {
        Listener target = listener;
        if (target != null) {
            int value = online;
            mainHandler.post(() -> target.onCountChanged(value));
        }
    }

    private void postMessage(ChatMessage message) {
        Listener target = listener;
        if (target != null) {
            mainHandler.post(() -> target.onMessage(message));
        }
    }

    private void postDisconnected(String reason) {
        Listener target = listener;
        if (target != null && running) {
            mainHandler.post(() -> target.onDisconnected(reason));
        }
    }

    public String getRoomName() {
        return roomName;
    }

    public String getRoomId() {
        return roomId;
    }

    public int getOnline() {
        return online;
    }

    private void closeSocket() {
        Socket value = socket;
        socket = null;
        if (value != null) {
            try {
                value.close();
            } catch (IOException ignored) {
            }
        }
    }

    @Override
    public void close() {
        running = false;
        connected = false;
        heartbeat.shutdownNow();
        sender.shutdownNow();
        closeSocket();
        listener = null;
    }
}
