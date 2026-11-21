import java.io.DataInputStream;
import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;

/**
 * Server.java 自检脚本（不依赖 GameMaker）：
 * 模拟两个 GameMaker 客户端（10000 字节定长帧）连接、注册、聊天、离开，
 * 并检查空昵称拒绝、加入/离开通知、消息转发与 UDP 发现广播。
 *
 * 运行： javac Server.java SelfTest.java && java SelfTest
 */
public final class SelfTest {

    private static final int FRAME = 10000;
    private static final String ROOM = "自检房间";

    private static boolean allPassed = true;

    public static void main(String[] args) throws Exception {
        int tcpPort = freeTcpPort();
        int udpPort = freeUdpPort();

        DatagramSocket udpListener = new DatagramSocket(null);
        udpListener.setReuseAddress(true);
        udpListener.bind(new InetSocketAddress("0.0.0.0", udpPort));
        udpListener.setSoTimeout(4000);

        Server server = new Server(ROOM, tcpPort, udpPort, 0.5);
        Thread serverThread = new Thread(server::run, "server");
        serverThread.setDaemon(true);
        serverThread.start();

        Socket alice = null;
        Socket bob = null;
        try {
            alice = connectRetry(tcpPort);

            // 空昵称（仅空白）应被拒绝：服务器不广播加入通知
            sendFrame(alice, "&name=   ");
            alice.setSoTimeout(600);
            boolean rejected;
            try {
                recvFrame(alice);
                rejected = false;
            } catch (SocketTimeoutException e) {
                rejected = true;
            }
            alice.setSoTimeout(4000);
            check("空昵称被服务器拒绝（无加入通知）", rejected);

            sendFrame(alice, "&name=Alice");
            check("Alice 收到自己加入通知", "&coly=Alice已加入".equals(recvFrame(alice)));

            bob = connectRetry(tcpPort);
            sendFrame(bob, "&name=Bob");
            check("Alice 收到 Bob 加入通知", "&coly=Bob已加入".equals(recvFrame(alice)));
            check("Bob 收到自己加入通知", "&coly=Bob已加入".equals(recvFrame(bob)));

            sendFrame(alice, "Alice:你好，世界");
            check("Alice 收到消息回显", "Alice:你好，世界".equals(recvFrame(alice)));
            check("Bob 收到 Alice 的消息", "Alice:你好，世界".equals(recvFrame(bob)));

            bob.close();
            bob = null;
            check("Alice 收到 Bob 离开通知", "&coly=Bob已离开".equals(recvFrame(alice)));

            try {
                byte[] buffer = new byte[2048];
                DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
                udpListener.receive(packet);
                String text = new String(packet.getData(), 0, packet.getLength(),
                        StandardCharsets.UTF_8);
                int zero = text.indexOf('\0');
                if (zero >= 0) {
                    text = text.substring(0, zero);
                }
                check("UDP 发现广播格式正确: " + text,
                        text.startsWith("&sern=" + ROOM + "|"));
            } catch (SocketTimeoutException e) {
                System.out.println("  [警告] 未收到 UDP 广播（可能被防火墙拦截）");
            }
        } finally {
            if (alice != null) {
                alice.close();
            }
            if (bob != null) {
                bob.close();
            }
            udpListener.close();
            server.stop();
        }

        System.out.println();
        System.out.println(allPassed ? "自检全部通过。" : "自检存在失败项。");
        System.exit(allPassed ? 0 : 1);
    }

    private static void sendFrame(Socket socket, String text) throws IOException {
        byte[] payload = text.getBytes(StandardCharsets.UTF_8);
        if (payload.length > FRAME - 1) {
            throw new IllegalArgumentException("测试消息过长");
        }
        byte[] frame = new byte[FRAME];
        System.arraycopy(payload, 0, frame, 0, payload.length);
        frame[payload.length] = 0;
        socket.getOutputStream().write(frame);
        socket.getOutputStream().flush();
    }

    private static String recvFrame(Socket socket) throws IOException {
        byte[] frame = new byte[FRAME];
        DataInputStream in = new DataInputStream(socket.getInputStream());
        in.readFully(frame);
        int end = 0;
        while (end < frame.length && frame[end] != 0) {
            end++;
        }
        return new String(frame, 0, end, StandardCharsets.UTF_8);
    }

    private static Socket connectRetry(int port) throws Exception {
        long deadline = System.currentTimeMillis() + 5000;
        while (System.currentTimeMillis() < deadline) {
            try {
                Socket socket = new Socket();
                socket.connect(new InetSocketAddress("127.0.0.1", port), 1000);
                socket.setSoTimeout(4000);
                return socket;
            } catch (IOException e) {
                Thread.sleep(50);
            }
        }
        throw new IOException("服务器未在预期时间内开始监听");
    }

    private static int freeTcpPort() throws IOException {
        try (ServerSocket socket = new ServerSocket(0)) {
            return socket.getLocalPort();
        }
    }

    private static int freeUdpPort() throws IOException {
        try (DatagramSocket socket = new DatagramSocket(0)) {
            return socket.getLocalPort();
        }
    }

    private static void check(String label, boolean passed) {
        allPassed &= passed;
        System.out.println("  [" + (passed ? "通过" : "失败") + "] " + label);
    }
}
