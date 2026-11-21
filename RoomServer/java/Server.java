import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketException;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

/**
 * ChatRoom 聊天室独立服务器（与 GameMaker 客户端兼容）。
 *
 * TCP 6510：客户端连接、昵称注册、聊天消息
 * UDP 6511：局域网房间发现广播（默认每秒一次，成员变化时立即补发）
 *
 * 所有字符串均为 UTF-8 + '\0' 结尾；收发均使用 10000 字节定长帧，
 * 与 GameMaker 内置服务端（obj_server）的行为保持一致。
 */
public final class Server {

    private static final int FRAME_SIZE = 10000;
    private static final int MAX_NAME_CHARS = 15;
    private static final String BROADCAST_ADDR = "255.255.255.255";

    /** 一个已连接的客户端。 */
    private static final class Client {
        final Socket socket;
        final OutputStream out;
        final String remoteIp;
        final Object sendLock = new Object();
        final ByteArrayOutputStream pending = new ByteArrayOutputStream();
        volatile String name;

        Client(Socket socket) throws IOException {
            this.socket = socket;
            this.out = socket.getOutputStream();
            this.remoteIp = socket.getInetAddress().getHostAddress();
        }

        String endpoint() {
            return remoteIp + ":" + socket.getPort();
        }
    }

    private final String roomName;
    private final String roomId;
    private final int port;
    private final int broadcastPort;
    private final long intervalMillis;

    private final List<Client> clients = new ArrayList<>();
    private final Object lock = new Object();
    private final Object printLock = new Object();
    private final Semaphore discoverySignal = new Semaphore(0);

    private volatile boolean running = true;
    private volatile boolean stopped = false;

    private ServerSocket serverSocket;
    private DatagramSocket udpSocket;
    private Thread discoveryThread;

    public Server(String roomName, int port, int broadcastPort, double intervalSeconds) {
        this.roomName = roomName;
        this.port = port;
        this.broadcastPort = broadcastPort;
        this.intervalMillis = Math.max(200L, (long) (intervalSeconds * 1000.0));

        SecureRandom random = new SecureRandom();
        String idChars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        StringBuilder id = new StringBuilder(20);
        for (int i = 0; i < 20; i++) {
            id.append(idChars.charAt(random.nextInt(idChars.length())));
        }
        this.roomId = id.toString();
    }

    // ==================== 启动 / 停止 ====================

    public void run() {
        if (!bindTcp()) {
            running = false;
            return;
        }
        if (!createUdp()) {
            running = false;
            closeQuietly(serverSocket);
            return;
        }

        discoveryThread = new Thread(this::discoveryLoop, "discovery");
        discoveryThread.setDaemon(true);
        discoveryThread.start();

        printBanner();

        while (running) {
            try {
                Socket socket = serverSocket.accept();
                socket.setTcpNoDelay(true);

                Client client = new Client(socket);
                synchronized (lock) {
                    clients.add(client);
                }
                log("[连接] " + client.endpoint());

                Thread thread = new Thread(() -> clientLoop(client), "client-" + socket.getPort());
                thread.setDaemon(true);
                thread.start();

                discoverySignal.release();
            } catch (IOException e) {
                if (running) {
                    log("[错误] 接受连接失败：" + e.getMessage());
                }
                break;
            }
        }

        stop();
    }

    public void stop() {
        synchronized (lock) {
            if (stopped) {
                return;
            }
            stopped = true;
            running = false;
        }

        discoverySignal.release();

        closeQuietly(serverSocket);
        if (udpSocket != null) {
            udpSocket.close();
        }

        List<Client> snapshot;
        synchronized (lock) {
            snapshot = new ArrayList<>(clients);
            clients.clear();
        }
        for (Client client : snapshot) {
            try {
                client.socket.close();
            } catch (IOException ignored) {
                // 已断开
            }
        }

        log("服务器已关闭。");
    }

    private boolean bindTcp() {
        try {
            serverSocket = new ServerSocket();
            serverSocket.setReuseAddress(true);
            serverSocket.bind(new InetSocketAddress("0.0.0.0", port), 20);
            return true;
        } catch (IOException e) {
            System.err.println("[错误] 无法绑定 TCP 端口 " + port + "：" + e.getMessage());
            System.err.println("提示：可能已有服务器（GameMaker 或另一个 server 实例）占用该端口。");
            return false;
        }
    }

    private boolean createUdp() {
        try {
            udpSocket = new DatagramSocket();
            udpSocket.setBroadcast(true);
            return true;
        } catch (SocketException e) {
            System.err.println("[错误] 无法创建 UDP 套接字：" + e.getMessage());
            return false;
        }
    }

    // ==================== 客户端处理 ====================

    private void clientLoop(Client client) {
        try {
            InputStream in = client.socket.getInputStream();
            byte[] chunk = new byte[65536];
            while (running) {
                int read = in.read(chunk);
                if (read < 0) {
                    break;
                }
                client.pending.write(chunk, 0, read);
                drainMessages(client);
            }
        } catch (IOException ignored) {
            // 连接断开或服务器关闭
        } finally {
            dropClient(client, "连接结束");
        }
    }

    /** 从接收缓冲区取出所有以 '\0' 结尾的消息，并忽略定长帧中的零填充。 */
    private void drainMessages(Client client) {
        byte[] data = client.pending.toByteArray();
        int start = 0;

        for (int i = 0; i < data.length; i++) {
            if (data[i] != 0) {
                continue;
            }
            if (i > start) {
                String text = new String(data, start, i - start, StandardCharsets.UTF_8).trim();
                if (!text.isEmpty()) {
                    handleMessage(client, text);
                }
            }
            start = i + 1;
            while (start < data.length && data[start] == 0) {
                start++;
            }
            i = start - 1;
        }

        client.pending.reset();
        if (start < data.length) {
            client.pending.write(data, start, data.length - start);
        }
    }

    private void handleMessage(Client client, String text) {
        if (text.startsWith("&name=")) {
            if (client.name != null) {
                return; // 已注册昵称，忽略重复注册
            }

            String name = text.substring(6).strip();
            if (name.isEmpty()) {
                return;
            }
            if (name.codePointCount(0, name.length()) > MAX_NAME_CHARS) {
                int end = name.offsetByCodePoints(0, 12);
                name = name.substring(0, end) + "...";
            }

            client.name = name;
            int online;
            synchronized (lock) {
                online = clients.size();
            }

            log("[加入] " + name + " (" + client.remoteIp + ")  在线 " + online + " 人");
            printMembers();
            broadcast("&coly=" + name + "已加入");
            discoverySignal.release();
            return;
        }

        log("[消息] " + text);
        broadcast(text);
    }

    /** 向所有客户端发送一条消息（10000 字节定长帧）。 */
    private void broadcast(String text) {
        byte[] payload = text.getBytes(StandardCharsets.UTF_8);
        if (payload.length > FRAME_SIZE - 1) {
            payload = Arrays.copyOf(payload, FRAME_SIZE - 1);
        }

        byte[] frame = new byte[FRAME_SIZE];
        System.arraycopy(payload, 0, frame, 0, payload.length);
        frame[payload.length] = 0;

        List<Client> snapshot;
        synchronized (lock) {
            snapshot = new ArrayList<>(clients);
        }

        List<Client> dead = null;
        for (Client client : snapshot) {
            try {
                synchronized (client.sendLock) {
                    client.out.write(frame);
                    client.out.flush();
                }
            } catch (IOException e) {
                if (dead == null) {
                    dead = new ArrayList<>();
                }
                dead.add(client);
            }
        }

        if (dead != null) {
            for (Client client : dead) {
                dropClient(client, "发送失败");
            }
        }
    }

    private void dropClient(Client client, String reason) {
        boolean removed;
        synchronized (lock) {
            removed = clients.remove(client);
        }
        if (!removed) {
            return;
        }

        try {
            client.socket.close();
        } catch (IOException ignored) {
            // 已断开
        }

        String name = client.name;
        if (name != null) {
            int online;
            synchronized (lock) {
                online = clients.size();
            }
            log("[离开] " + name + " (" + client.remoteIp + ") - " + reason + "  在线 " + online + " 人");
            printMembers();
            broadcast("&coly=" + name + "已离开");
        } else {
            log("[断开] " + client.endpoint() + " - " + reason);
        }

        discoverySignal.release();
    }

    // ==================== 发现广播 ====================

    private void discoveryLoop() {
        sendDiscovery(); // 启动后立即广播一次

        while (running) {
            try {
                discoverySignal.tryAcquire(intervalMillis, TimeUnit.MILLISECONDS);
            } catch (InterruptedException e) {
                break;
            }
            if (!running) {
                break;
            }
            discoverySignal.drainPermits(); // 合并短时间内的多次变化
            sendDiscovery();
        }
    }

    private void sendDiscovery() {
        int online;
        synchronized (lock) {
            online = clients.size();
        }

        byte[] text = ("&sern=" + roomName + "|" + online + "|" + port + "|" + roomId)
                .getBytes(StandardCharsets.UTF_8);
        byte[] data = Arrays.copyOf(text, text.length + 1); // 末位保持 0

        // 同时发往受限广播地址和各网卡的定向广播地址，
        // 避免多网卡（虚拟网卡 / VPN）环境下广播从错误的接口发出。
        for (InetAddress target : discoveryTargets()) {
            try {
                udpSocket.send(new DatagramPacket(data, data.length, target, broadcastPort));
            } catch (IOException ignored) {
                // 单个接口发送失败不影响其它接口
            }
        }
    }

    private static List<InetAddress> discoveryTargets() {
        List<InetAddress> targets = new ArrayList<>();
        Set<String> seen = new TreeSet<>();

        try {
            InetAddress limited = InetAddress.getByName(BROADCAST_ADDR);
            targets.add(limited);
            seen.add(limited.getHostAddress());
        } catch (IOException ignored) {
            // 继续使用网卡定向广播
        }

        try {
            for (NetworkInterface network : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!network.isUp() || network.isLoopback()) {
                    continue;
                }
                for (InterfaceAddress address : network.getInterfaceAddresses()) {
                    InetAddress broadcast = address.getBroadcast();
                    if (broadcast != null && seen.add(broadcast.getHostAddress())) {
                        targets.add(broadcast);
                    }
                }
            }
        } catch (SocketException ignored) {
            // 使用已收集到的目标
        }

        return targets;
    }

    // ==================== 控制台输出 ====================

    private void printBanner() {
        log("");
        log("==========================================================");
        log("            ChatRoom 聊天室服务器");
        log("  房间名称 : " + roomName);
        log("  TCP 端口 : " + port + "   (客户端连接)");
        log("  UDP 端口 : " + broadcastPort + "   (局域网广播)");
        for (String ip : localIpv4()) {
            log("  本机地址 : " + ip);
        }
        log("==========================================================");
        log("等待客户端连接... (Ctrl+C 退出)");
        log("");
    }

    private void printMembers() {
        List<Client> snapshot;
        synchronized (lock) {
            snapshot = new ArrayList<>(clients);
        }

        synchronized (printLock) {
            int count = 0;
            for (Client client : snapshot) {
                if (client.name != null) {
                    count++;
                }
            }

            StringBuilder sb = new StringBuilder();
            sb.append("--- 在线成员 (").append(count).append(") ---\n");
            int index = 0;
            for (Client client : snapshot) {
                if (client.name != null) {
                    index++;
                    sb.append(String.format("  %2d. %s  (%s)%n", index, client.name, client.remoteIp));
                }
            }
            sb.append("------------------------------");
            System.out.println(sb);
            System.out.flush();
        }
    }

    private void log(String message) {
        synchronized (printLock) {
            System.out.println(message);
            System.out.flush();
        }
    }

    private static List<String> localIpv4() {
        Set<String> result = new TreeSet<>();
        try {
            for (NetworkInterface network : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!network.isUp()) {
                    continue;
                }
                for (InterfaceAddress address : network.getInterfaceAddresses()) {
                    InetAddress inet = address.getAddress();
                    if (inet instanceof Inet4Address
                            && !inet.isLoopbackAddress()
                            && !inet.isLinkLocalAddress()) {
                        result.add(inet.getHostAddress());
                    }
                }
            }
        } catch (SocketException ignored) {
            // 忽略
        }
        return new ArrayList<>(result);
    }

    private static void closeQuietly(ServerSocket socket) {
        if (socket == null) {
            return;
        }
        try {
            socket.close();
        } catch (IOException ignored) {
            // 忽略
        }
    }

    // ==================== 命令行入口 ====================

    public static void main(String[] args) {
        String name = null;
        int port = 6510;
        int broadcastPort = 6511;
        double interval = 1.0;

        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            try {
                switch (arg) {
                    case "--name":
                    case "-n":
                        name = i + 1 < args.length ? args[++i] : null;
                        break;
                    case "--port":
                    case "-p":
                        port = Integer.parseInt(args[++i]);
                        break;
                    case "--broadcast-port":
                    case "-b":
                        broadcastPort = Integer.parseInt(args[++i]);
                        break;
                    case "--interval":
                    case "-i":
                        interval = Double.parseDouble(args[++i]);
                        break;
                    case "--help":
                    case "-h":
                        printUsage();
                        return;
                    default:
                        System.out.println("未知参数：" + arg);
                        printUsage();
                        return;
                }
            } catch (ArrayIndexOutOfBoundsException | NumberFormatException e) {
                System.out.println("参数格式错误：" + arg);
                printUsage();
                return;
            }
        }

        if (name == null || name.strip().isEmpty()) {
            name = "";
            if (System.console() != null) {
                String input = System.console().readLine("请输入聊天室名称: ");
                if (input != null) {
                    name = input.strip();
                }
            }
            if (name.isEmpty()) {
                name = "ChatRoom 聊天室";
            }
        }

        Server server = new Server(name.strip(), port, broadcastPort, interval);
        Runtime.getRuntime().addShutdownHook(new Thread(server::stop));
        server.run();
    }

    private static void printUsage() {
        System.out.println("用法: java Server.java [选项]");
        System.out.println("  --name, -n <名称>            聊天室名称");
        System.out.println("  --port, -p <端口>            TCP 监听端口（默认 6510）");
        System.out.println("  --broadcast-port, -b <端口>  UDP 广播端口（默认 6511）");
        System.out.println("  --interval, -i <秒>          广播间隔（默认 1.0）");
    }
}
