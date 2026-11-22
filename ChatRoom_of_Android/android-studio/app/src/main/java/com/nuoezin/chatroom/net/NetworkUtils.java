package com.nuoezin.chatroom.net;

import android.os.Build;

import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

public final class NetworkUtils {
    private NetworkUtils() {
    }

    public static List<String> localIpv4Addresses() {
        Set<String> addresses = new LinkedHashSet<>();
        try {
            for (NetworkInterface network : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!network.isUp() || network.isLoopback()) {
                    continue;
                }
                for (InetAddress address : Collections.list(network.getInetAddresses())) {
                    if (address instanceof Inet4Address
                            && !address.isLoopbackAddress()
                            && !address.isLinkLocalAddress()) {
                        addresses.add(address.getHostAddress());
                    }
                }
            }
        } catch (Exception ignored) {
        }
        return new ArrayList<>(addresses);
    }

    public static String primaryIpv4() {
        List<String> addresses = localIpv4Addresses();
        return addresses.isEmpty() ? "127.0.0.1" : addresses.get(0);
    }

    /**
     * 模拟器中的 127.0.0.1 指向模拟器自身，宿主机需要通过 10.0.2.2 访问。
     */
    public static String effectiveHost(String host) {
        if (!isEmulator() || host == null) {
            return host;
        }
        String value = host.trim();
        if ("127.0.0.1".equals(value) || "localhost".equalsIgnoreCase(value)) {
            return "10.0.2.2";
        }
        return value;
    }

    public static boolean isEmulator() {
        String fingerprint = Build.FINGERPRINT == null ? "" : Build.FINGERPRINT.toLowerCase();
        String model = Build.MODEL == null ? "" : Build.MODEL.toLowerCase();
        String product = Build.PRODUCT == null ? "" : Build.PRODUCT.toLowerCase();
        String hardware = Build.HARDWARE == null ? "" : Build.HARDWARE.toLowerCase();
        String manufacturer = Build.MANUFACTURER == null
                ? "" : Build.MANUFACTURER.toLowerCase();
        return fingerprint.startsWith("generic")
                || fingerprint.contains("emulator")
                || fingerprint.contains("vbox")
                || model.contains("sdk_gphone")
                || model.contains("emulator")
                || product.contains("sdk_gphone")
                || product.contains("emulator")
                || product.contains("simulator")
                || hardware.contains("goldfish")
                || hardware.contains("ranchu")
                || manufacturer.contains("genymotion");
    }

    /**
     * 当 UDP 广播被路由器、防火墙或模拟器 NAT 拦截时，用 TCP 端口探测兜底。
     */
    public static List<String> scanHostCandidates() {
        Set<String> candidates = new LinkedHashSet<>();
        if (isEmulator()) {
            candidates.add("10.0.2.2");
            candidates.add("10.0.3.2");
        }
        for (String address : localIpv4Addresses()) {
            byte[] bytes = ipv4Bytes(address);
            if (bytes == null) {
                continue;
            }
            int own = bytes[3] & 0xFF;
            for (int host = 1; host <= 254; host++) {
                if (host == own) {
                    continue;
                }
                candidates.add((bytes[0] & 0xFF) + "." + (bytes[1] & 0xFF) + "."
                        + (bytes[2] & 0xFF) + "." + host);
                if (candidates.size() >= 600) {
                    return new ArrayList<>(candidates);
                }
            }
        }
        return new ArrayList<>(candidates);
    }

    private static byte[] ipv4Bytes(String address) {
        if (address == null) {
            return null;
        }
        String[] parts = address.split("\\.");
        if (parts.length != 4) {
            return null;
        }
        byte[] result = new byte[4];
        try {
            for (int i = 0; i < 4; i++) {
                int value = Integer.parseInt(parts[i]);
                if (value < 0 || value > 255) {
                    return null;
                }
                result[i] = (byte) value;
            }
        } catch (NumberFormatException error) {
            return null;
        }
        if ((result[0] & 0xFF) == 127 || (result[0] & 0xFF) == 0) {
            return null;
        }
        return result;
    }
}
