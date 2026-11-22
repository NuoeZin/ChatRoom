package com.nuoezin.chatroom.net;

import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import com.nuoezin.chatroom.R;
import com.nuoezin.chatroom.model.RoomInfo;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public final class RoomDiscovery implements AutoCloseable {
    public interface Listener {
        void onRoomsChanged(List<RoomInfo> rooms);
    }

    private final Map<String, RoomInfo> rooms = new ConcurrentHashMap<>();
    private final Map<String, RoomInfo> fallbackRooms = new ConcurrentHashMap<>();
    private final Context appContext;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ScheduledExecutorService cleaner =
            Executors.newSingleThreadScheduledExecutor(r -> {
                Thread thread = new Thread(r, "chatroom-discovery-cleaner");
                thread.setDaemon(true);
                return thread;
            });
    private final ScheduledExecutorService scanner =
            Executors.newSingleThreadScheduledExecutor(r -> {
                Thread thread = new Thread(r, "chatroom-discovery-scan");
                thread.setDaemon(true);
                return thread;
            });
    private volatile boolean running;
    private volatile DatagramSocket socket;
    private volatile Listener listener;
    private WifiManager.MulticastLock multicastLock;

    public RoomDiscovery(Context context, Listener listener) {
        this.appContext = context.getApplicationContext();
        this.listener = listener;
    }

    public void start() {
        if (running) {
            return;
        }
        running = true;
        acquireMulticastLock();
        Thread thread = new Thread(this::receiveLoop, "chatroom-discovery");
        thread.setDaemon(true);
        thread.start();
        cleaner.scheduleAtFixedRate(this::cleanStale, 1, 1, TimeUnit.SECONDS);
        scanner.scheduleWithFixedDelay(this::scanFallback, 2, 6, TimeUnit.SECONDS);
    }

    private void receiveLoop() {
        try {
            DatagramSocket value = new DatagramSocket(null);
            value.setReuseAddress(true);
            value.setBroadcast(true);
            value.setReceiveBufferSize(65536);
            value.bind(new InetSocketAddress(Protocol.BROADCAST_PORT));
            socket = value;
            Log.i("RoomDiscovery", "Listening on UDP " + Protocol.BROADCAST_PORT);
            byte[] buffer = new byte[2048];
            while (running) {
                DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
                value.receive(packet);
                String payload = new String(
                        packet.getData(), 0, packet.getLength(), StandardCharsets.UTF_8
                ).trim();
                parse(payload, packet.getAddress().getHostAddress());
            }
        } catch (IOException error) {
            Log.w("RoomDiscovery", "Discovery listener failed", error);
            if (running) {
                postRooms(new ArrayList<>());
            }
        }
    }

    private void parse(String payload, String address) {
        if (!payload.startsWith("&sern=")) {
            return;
        }
        String[] parts = payload.substring(6).split("\\|", 4);
        if (parts.length < 4) {
            return;
        }
        try {
            String name = parts[0];
            int players = Integer.parseInt(parts[1]);
            int port = Integer.parseInt(parts[2]);
            String id = parts[3];
            if (port <= 0 || port > 65535) {
                port = Protocol.DEFAULT_PORT;
            }
            if (id.length() != 20) {
                id = "";
            }
            RoomInfo info = new RoomInfo(
                    name,
                    address,
                    port,
                    players,
                    id,
                    SystemClock.elapsedRealtime()
            );
            rooms.put(info.key(), info);
            Log.i("RoomDiscovery", "Found " + info.name + " at " + address + ":" + port);
            postRooms(snapshot());
        } catch (NumberFormatException ignored) {
        }
    }

    private void cleanStale() {
        if (!running) {
            return;
        }
        long now = SystemClock.elapsedRealtime();
        boolean changed = rooms.entrySet().removeIf(entry -> now - entry.getValue().lastSeen > 6500);
        changed |= fallbackRooms.entrySet().removeIf(
                entry -> now - entry.getValue().lastSeen > 14000
        );
        if (changed) {
            postRooms(snapshot());
        }
    }

    /**
     * 部分路由器会拦截 UDP 广播，Android 模拟器的 NAT 也不会把宿主机广播送进虚拟机。
     * 在没有收到任何广播时，用 TCP 探测本网段与模拟器宿主机地址作为兜底。
     */
    private void scanFallback() {
        if (!running) {
            return;
        }
        if (!rooms.isEmpty()) {
            if (!fallbackRooms.isEmpty()) {
                fallbackRooms.clear();
                postRooms(snapshot());
            }
            return;
        }

        List<String> candidates = NetworkUtils.scanHostCandidates();
        if (candidates.isEmpty()) {
            return;
        }

        Set<String> found = ConcurrentHashMap.newKeySet();
        ExecutorService probe = Executors.newFixedThreadPool(32, r -> {
            Thread thread = new Thread(r, "chatroom-discovery-probe");
            thread.setDaemon(true);
            return thread;
        });
        for (String address : candidates) {
            probe.execute(() -> {
                if (tcpReachable(address, Protocol.DEFAULT_PORT)) {
                    found.add(address);
                }
            });
        }
        probe.shutdown();
        try {
            probe.awaitTermination(8, TimeUnit.SECONDS);
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            probe.shutdownNow();
            return;
        }

        if (!running || !rooms.isEmpty()) {
            return;
        }
        long now = SystemClock.elapsedRealtime();
        String label = appContext.getString(R.string.lan_discovered_room);
        for (String address : found) {
            String key = address + ":" + Protocol.DEFAULT_PORT;
            fallbackRooms.put(
                    key,
                    new RoomInfo(label, address, Protocol.DEFAULT_PORT, 0, "", now)
            );
            Log.i("RoomDiscovery", "TCP fallback found " + key);
        }
        if (!found.isEmpty()) {
            postRooms(snapshot());
        }
    }

    private boolean tcpReachable(String address, int port) {
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress(address, port), 260);
            return true;
        } catch (IOException ignored) {
            return false;
        }
    }

    public List<RoomInfo> snapshot() {
        List<RoomInfo> result = new ArrayList<>(rooms.values());
        Set<String> exact = new HashSet<>();
        for (RoomInfo room : result) {
            exact.add(room.address + ":" + room.port);
        }
        for (RoomInfo room : fallbackRooms.values()) {
            if (!exact.contains(room.address + ":" + room.port)) {
                result.add(room);
            }
        }
        result.sort(Comparator.comparing(room -> room.name.toLowerCase()));
        return result;
    }

    private void postRooms(List<RoomInfo> value) {
        Listener target = listener;
        if (target != null) {
            mainHandler.post(() -> target.onRoomsChanged(value));
        }
    }

    @Override
    public void close() {
        running = false;
        cleaner.shutdownNow();
        scanner.shutdownNow();
        fallbackRooms.clear();
        releaseMulticastLock();
        DatagramSocket value = socket;
        socket = null;
        if (value != null) {
            value.close();
        }
        listener = null;
    }

    private void acquireMulticastLock() {
        try {
            WifiManager wifi = (WifiManager) appContext.getSystemService(Context.WIFI_SERVICE);
            if (wifi == null) {
                return;
            }
            multicastLock = wifi.createMulticastLock("chatroom-discovery");
            multicastLock.setReferenceCounted(false);
            multicastLock.acquire();
        } catch (Exception error) {
            Log.w("RoomDiscovery", "Unable to acquire multicast lock", error);
        }
    }

    private void releaseMulticastLock() {
        if (multicastLock != null) {
            try {
                if (multicastLock.isHeld()) {
                    multicastLock.release();
                }
            } finally {
                multicastLock = null;
            }
        }
    }
}
