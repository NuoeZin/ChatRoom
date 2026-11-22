package com.nuoezin.chatroom.net;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;

import com.nuoezin.chatroom.model.ChatMessage;
import com.nuoezin.chatroom.model.Member;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

public final class RoomHost implements AutoCloseable {
    public interface Listener {
        void onSnapshot(Snapshot snapshot);

        void onMessage(ChatMessage message);
    }

    public static final class Snapshot {
        public final String roomName;
        public final String roomId;
        public final List<Member> members;
        public final List<String> localAddresses;
        public final long uptimeMillis;
        public final boolean running;

        Snapshot(String roomName, String roomId, List<Member> members,
                 List<String> localAddresses, long uptimeMillis, boolean running) {
            this.roomName = roomName;
            this.roomId = roomId;
            this.members = members;
            this.localAddresses = localAddresses;
            this.uptimeMillis = uptimeMillis;
            this.running = running;
        }

        public int onlineCount() {
            return members.size();
        }
    }

    private static final class ClientConnection {
        final Socket socket;
        final String address;
        final OutputStream output;
        volatile String name;

        ClientConnection(Socket socket) throws IOException {
            this.socket = socket;
            this.address = socket.getInetAddress().getHostAddress();
            this.output = socket.getOutputStream();
        }
    }

    private final String roomName;
    private final String roomId;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Set<ClientConnection> clients = ConcurrentHashMap.newKeySet();
    private final CopyOnWriteArrayList<ChatMessage> history = new CopyOnWriteArrayList<>();
    private final CopyOnWriteArrayList<Listener> listeners = new CopyOnWriteArrayList<>();
    private final java.util.concurrent.ExecutorService sender =
            java.util.concurrent.Executors.newSingleThreadExecutor(r -> {
                Thread thread = new Thread(r, "chatroom-host-sender");
                thread.setDaemon(true);
                return thread;
            });
    private final long startedAt = SystemClock.elapsedRealtime();
    private volatile boolean running;
    private volatile boolean hostPresent;
    private ServerSocket serverSocket;
    private DatagramSocket broadcastSocket;
    private Thread acceptThread;
    private Thread broadcastThread;

    public RoomHost(String roomName) {
        String value = roomName == null ? "" : roomName.trim();
        this.roomName = value.length() > 30 ? value.substring(0, 30) : value;
        this.roomId = Protocol.roomId();
    }

    public void start() throws IOException {
        if (running) {
            return;
        }

        serverSocket = new ServerSocket();
        serverSocket.setReuseAddress(true);
        serverSocket.bind(new InetSocketAddress(Protocol.DEFAULT_PORT), 20);

        broadcastSocket = new DatagramSocket();
        broadcastSocket.setBroadcast(true);
        running = true;

        acceptThread = new Thread(this::acceptLoop, "chatroom-host-accept");
        acceptThread.setDaemon(true);
        acceptThread.start();

        broadcastThread = new Thread(this::broadcastLoop, "chatroom-host-broadcast");
        broadcastThread.setDaemon(true);
        broadcastThread.start();
        notifySnapshot();
    }

    public void addListener(Listener listener) {
        if (listener == null) {
            return;
        }
        listeners.addIfAbsent(listener);
        Listener current = listener;
        mainHandler.post(() -> current.onSnapshot(snapshot()));
    }

    public void removeListener(Listener listener) {
        listeners.remove(listener);
    }

    public List<ChatMessage> getHistory() {
        return new ArrayList<>(history);
    }

    public Snapshot snapshot() {
        List<Member> members = new ArrayList<>();
        if (hostPresent) {
            members.add(new Member("房主（你）", NetworkUtils.primaryIpv4(), true));
        }
        List<ClientConnection> registered = new ArrayList<>();
        for (ClientConnection client : clients) {
            if (client.name != null && !client.name.isEmpty()) {
                registered.add(client);
            }
        }
        registered.sort((a, b) -> a.name.compareToIgnoreCase(b.name));
        for (ClientConnection client : registered) {
            members.add(new Member(client.name, client.address, false));
        }
        return new Snapshot(roomName, roomId, members,
                NetworkUtils.localIpv4Addresses(),
                Math.max(0, SystemClock.elapsedRealtime() - startedAt), running);
    }

    public boolean isRunning() {
        return running;
    }

    public String getRoomName() {
        return roomName;
    }

    public String getRoomId() {
        return roomId;
    }

    public int registeredCount() {
        int count = hostPresent ? 1 : 0;
        for (ClientConnection client : clients) {
            if (client.name != null && !client.name.isEmpty()) {
                count++;
            }
        }
        return count;
    }

    public void sendAsHost(String nickname, String text) {
        String safeName = Protocol.sanitizeName(nickname);
        String safeText = text == null ? "" : text.trim();
        if (safeText.isEmpty()) {
            return;
        }
        String payload = safeName + ":" + safeText;
        broadcast(payload);
        appendMessage(ChatMessage.self(safeName, safeText));
    }

    public void setHostPresent(boolean present) {
        if (hostPresent == present) {
            return;
        }
        hostPresent = present;
        broadcastCount();
        notifySnapshot();
    }

    private void acceptLoop() {
        while (running) {
            try {
                Socket socket = serverSocket.accept();
                socket.setTcpNoDelay(true);
                ClientConnection client = new ClientConnection(socket);
                clients.add(client);
                Thread reader = new Thread(() -> readClient(client), "chatroom-client-reader");
                reader.setDaemon(true);
                reader.start();
            } catch (IOException error) {
                if (running) {
                    postError("房间监听已停止");
                }
                return;
            }
        }
    }

    private void readClient(ClientConnection client) {
        Protocol.MessageStream stream = new Protocol.MessageStream();
        byte[] buffer = new byte[8192];
        try (InputStream input = client.socket.getInputStream()) {
            int read;
            while (running && (read = input.read(buffer)) >= 0) {
                for (String message : stream.feed(buffer, read)) {
                    handleClientMessage(client, message);
                }
            }
        } catch (IOException ignored) {
        } finally {
            disconnectClient(client);
        }
    }

    private void handleClientMessage(ClientConnection client, String message) {
        if (message.startsWith("&ping=")) {
            try {
                Protocol.write(client.output, "&pong=" + message.substring(6), false);
            } catch (IOException ignored) {
                closeClient(client);
            }
            return;
        }

        if (message.startsWith("&name=")) {
            if (client.name != null) {
                return;
            }
            String name = Protocol.sanitizeName(message.substring(6));
            if (name.isEmpty()) {
                return;
            }
            client.name = name;
            String notice = "&coly=" + name + "已加入";
            broadcast(notice);
            appendMessage(ChatMessage.system(name + "已加入"));
            broadcastCount();
            notifySnapshot();
            return;
        }

        broadcast(message);
        int colon = message.indexOf(':');
        if (colon > 0) {
            appendMessage(ChatMessage.other(message.substring(0, colon), message.substring(colon + 1)));
        } else if (!message.startsWith("&")) {
            appendMessage(ChatMessage.other("访客", message));
        }
    }

    private void disconnectClient(ClientConnection client) {
        if (!clients.remove(client)) {
            return;
        }
        closeClient(client);
        if (client.name != null && !client.name.isEmpty()) {
            String notice = "&coly=" + client.name + "已离开";
            broadcast(notice);
            appendMessage(ChatMessage.system(client.name + "已离开"));
            broadcastCount();
        }
        notifySnapshot();
    }

    private void broadcastLoop() {
        while (running) {
            broadcastDiscovery();
            try {
                Thread.sleep(1000);
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt();
                return;
            }
        }
    }

    private void broadcastDiscovery() {
        DatagramSocket socket = broadcastSocket;
        if (socket == null || socket.isClosed()) {
            return;
        }
        String payload = "&sern=" + roomName + "|" + registeredCount() + "|"
                + Protocol.DEFAULT_PORT + "|" + roomId;
        byte[] data = Protocol.smallFrame(payload);
        try {
            socket.send(new DatagramPacket(
                    data,
                    data.length,
                    InetAddress.getByName("255.255.255.255"),
                    Protocol.BROADCAST_PORT
            ));
        } catch (IOException ignored) {
        }
    }

    private void broadcastCount() {
        broadcast("&count=" + registeredCount());
    }

    private void broadcast(String payload) {
        if (!running) {
            return;
        }
        try {
            sender.execute(() -> {
                for (ClientConnection client : clients) {
                    try {
                        Protocol.write(client.output, payload, false);
                    } catch (IOException error) {
                        closeClient(client);
                    }
                }
            });
        } catch (java.util.concurrent.RejectedExecutionException ignored) {
        }
    }

    private void appendMessage(ChatMessage message) {
        history.add(message);
        if (history.size() > 200) {
            history.remove(0);
        }
        mainHandler.post(() -> {
            for (Listener listener : listeners) {
                listener.onMessage(message);
            }
        });
    }

    private void notifySnapshot() {
        Snapshot value = snapshot();
        mainHandler.post(() -> {
            for (Listener listener : listeners) {
                listener.onSnapshot(value);
            }
        });
    }

    private void postError(String text) {
        appendMessage(ChatMessage.system(text));
    }

    private static void closeClient(ClientConnection client) {
        try {
            client.socket.close();
        } catch (IOException ignored) {
        }
    }

    @Override
    public void close() {
        if (!running && serverSocket == null) {
            return;
        }
        running = false;
        hostPresent = false;
        try {
            if (serverSocket != null) {
                serverSocket.close();
            }
        } catch (IOException ignored) {
        }
        if (broadcastSocket != null) {
            broadcastSocket.close();
        }
        for (ClientConnection client : clients) {
            closeClient(client);
        }
        clients.clear();
        sender.shutdownNow();
        notifySnapshot();
    }
}
