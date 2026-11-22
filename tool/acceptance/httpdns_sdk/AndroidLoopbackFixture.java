package com.zolmid.zolnit.httpdnsfixture;

import android.app.Activity;
import android.net.Uri;
import android.os.Bundle;
import android.security.NetworkSecurityPolicy;
import android.util.Log;
import com.alibaba.pdns.DNSResolver;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;
import org.json.*;

public final class AndroidLoopbackFixture extends Activity {
    private static final String HOST = "fixture.nodes.zolmid.com";
    private final List<JSONObject> requests = new CopyOnWriteArrayList<>();
    private String keyId;
    private String secret;
    private volatile boolean running = true;
    private ServerSocket listener;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        new Thread(this::runFixture, "cloud-dns-fixture").start();
    }

    private static String digest(String value) throws Exception {
        byte[] data = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
        StringBuilder text = new StringBuilder();
        for (byte item : data) text.append(String.format(Locale.ROOT, "%02x", item & 255));
        return text.toString();
    }

    private void runFixture() {
        JSONObject result = new JSONObject();
        try {
            byte[] entropy = new byte[32];
            new SecureRandom().nextBytes(entropy);
            secret = digest(Arrays.toString(entropy));
            new SecureRandom().nextBytes(entropy);
            keyId = digest(Arrays.toString(entropy));
            Arrays.fill(entropy, (byte)0);
            NetworkSecurityPolicy policy = NetworkSecurityPolicy.getInstance();
            result.put("loopbackCleartext", policy.isCleartextTrafficPermitted("127.0.0.1"));
            result.put("remoteHostCleartext", policy.isCleartextTrafficPermitted("example.com"));
            result.put("remoteIpCleartext", policy.isCleartextTrafficPermitted("192.0.2.3"));
            listener = new ServerSocket(0, 8, InetAddress.getByAddress(new byte[]{127, 0, 0, 1}));
            result.put("boundLoopback", listener.getInetAddress().isLoopbackAddress());
            new Thread(() -> {
                while (running) {
                    try { serve(listener.accept()); }
                    catch (Exception ignored) { }
                }
            }, "cloud-dns-fixture-server").start();
            DNSResolver.setEnableCache(true);
            DNSResolver.setMinTtlCache(0);
            DNSResolver.setMaxTtlCache(1);
            DNSResolver.setEnableLogger(false);
            DNSResolver.setEnableLocalDns(false);
            DNSResolver.setSchemaType(DNSResolver.HTTP);
            DNSResolver.setEnableSpeedTest(false);
            DNSResolver.setImmutableCacheEnable(false);
            DNSResolver.setKeepAliveDomains(new String[0]);
            DNSResolver.setTimeout(2);
            DNSResolver.InitFusionDNS(getApplicationContext(), new String[]{"127.0.0.1"}, null, null,
                Integer.toString(listener.getLocalPort()), HOST, keyId, secret);
            DNSResolver.setEnableCache(true);
            DNSResolver.setMinTtlCache(0);
            DNSResolver.setMaxTtlCache(1);
            DNSResolver.setEnableLogger(false);
            DNSResolver.setEnableLocalDns(false);
            DNSResolver.setSchemaType(DNSResolver.HTTP);
            DNSResolver.setEnableSpeedTest(false);
            if (DNSResolver.getEnableCache()) DNSResolver.getInstance().clear();
            Class<?> fusion = Class.forName("com.alibaba.pdns.manager.f");
            Object provider = fusion.getMethod("x").invoke(null);
            Map<?, ?> endpoint = (Map<?, ?>)fusion.getMethod("a", int.class).invoke(provider, 0);
            if (endpoint != null) {
                Uri configured = Uri.parse(String.valueOf(endpoint.get("URL")));
                result.put("configuredHttpLoopback", "http".equals(configured.getScheme()) && "127.0.0.1".equals(configured.getHost()));
            }
            Thread.sleep(1500);
            result.put("sdkNetworkType", DNSResolver.getInstance().mCurNetworkType);
            String[] values = DNSResolver.getInstance().getIPsV4ByHost(HOST);
            result.put("answers", values == null ? new JSONArray() : new JSONArray(Arrays.asList(values)));
            String[] ipv6 = DNSResolver.getInstance().getIPsV6ByHost(HOST);
            result.put("answers6", ipv6 == null ? new JSONArray() : new JSONArray(Arrays.asList(ipv6)));
            String[] automatic = DNSResolver.getInstance().getIpsByHost(HOST);
            result.put("automaticAnswers", automatic == null ? new JSONArray() : new JSONArray(Arrays.asList(automatic)));
            result.put("badAuthStatus", rejectProbe(HOST, false));
            result.put("unownedStatus", rejectProbe("example.com", true));
            result.put("credentialsPersisted", credentialsPersisted(getFilesDir()) ||
                credentialsPersisted(new File(getApplicationInfo().dataDir, "shared_prefs")) || credentialsPersisted(getCacheDir()));
            result.put("localDnsDisabled", !DNSResolver.getEnableLocalDns());
            result.put("schemeHttp", DNSResolver.HTTP.equals(DNSResolver.getSchemaType()));
            result.put("requests", new JSONArray(requests));
            result.put("passed", values != null && Arrays.asList(values).contains("192.0.2.10") &&
                ipv6 != null && Arrays.asList(ipv6).contains("2001:db8::10") &&
                result.getInt("badAuthStatus") == 403 && result.getInt("unownedStatus") == 403 &&
                !result.getBoolean("credentialsPersisted") &&
                !policy.isCleartextTrafficPermitted("example.com") && !policy.isCleartextTrafficPermitted("192.0.2.3"));
        } catch (Throwable error) {
            try { result.put("errorClass", error.getClass().getName()); result.put("requests", new JSONArray(requests)); }
            catch (Exception ignored) { }
        } finally {
            running = false;
            try { if (listener != null) listener.close(); } catch (Exception ignored) { }
            secret = null;
            keyId = null;
        }
        try (FileOutputStream file = openFileOutput("result.json", MODE_PRIVATE)) {
            file.write(result.toString().getBytes(StandardCharsets.UTF_8));
            Log.i("ZolNitDnsFixture", result.toString());
        } catch (Exception ignored) { }
    }

    private int rejectProbe(String name, boolean signed) throws Exception {
        String ts = Long.toString(System.currentTimeMillis() / 1000);
        String signature = signed ? digest("1" + secret + ts + name + keyId) : "invalid";
        URL url = new URL("http://127.0.0.1:" + listener.getLocalPort() +
            "/resolve?name=" + name + "&type=1&uid=1&ts=" + ts + "&ak=" + keyId + "&key=" + signature);
        HttpURLConnection request = (HttpURLConnection)url.openConnection();
        request.setConnectTimeout(1000);
        request.setReadTimeout(1000);
        request.setInstanceFollowRedirects(false);
        try { return request.getResponseCode(); } finally { request.disconnect(); }
    }

    private boolean credentialsPersisted(File entry) throws Exception {
        if (!entry.exists()) return false;
        if (entry.isDirectory()) {
            File[] children = entry.listFiles();
            if (children != null) for (File child : children) if (credentialsPersisted(child)) return true;
            return false;
        }
        if (entry.length() > 5 * 1024 * 1024) throw new IOException("fixture scan bound");
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (InputStream input = new FileInputStream(entry)) {
            byte[] chunk = new byte[4096]; int count;
            while ((count = input.read(chunk)) != -1) bytes.write(chunk, 0, count);
        }
        String text = new String(bytes.toByteArray(), StandardCharsets.ISO_8859_1);
        return text.contains(secret) || text.contains(keyId);
    }

    private void serve(Socket socket) throws Exception {
        try (Socket peer = socket) {
            peer.setSoTimeout(3000);
            BufferedReader reader = new BufferedReader(new InputStreamReader(peer.getInputStream(), StandardCharsets.US_ASCII));
            String line = reader.readLine();
            if (line == null || line.length() > 8192) return;
            String[] request = line.split(" ");
            Uri uri = Uri.parse(request[1]);
            String hostHeader = "";
            int count = line.length();
            while ((line = reader.readLine()) != null && !line.isEmpty()) {
                count += line.length();
                if (count > 8192) return;
                if (line.toLowerCase(Locale.ROOT).startsWith("host:")) hostHeader = line.substring(5).trim();
            }
            String name = uri.getQueryParameter("name");
            String type = uri.getQueryParameter("type");
            String timestamp = uri.getQueryParameter("ts");
            String providedKey = uri.getQueryParameter("ak");
            String signature = uri.getQueryParameter("key");
            boolean valid = peer.getInetAddress().isLoopbackAddress() &&
                hostHeader.equals("127.0.0.1:" + listener.getLocalPort()) &&
                "GET".equals(request[0]) && request[1].startsWith("/resolve?") &&
                "/resolve".equals(uri.getPath()) && HOST.equals(name) &&
                keyId.equals(providedKey) && timestamp != null && signature != null &&
                Math.abs(System.currentTimeMillis() / 1000 - Long.parseLong(timestamp)) <= 10 &&
                MessageDigest.isEqual(digest("1" + secret + timestamp + name + keyId).getBytes(StandardCharsets.US_ASCII),
                    signature.toLowerCase(Locale.ROOT).getBytes(StandardCharsets.US_ASCII));
            JSONObject trace = new JSONObject().put("path", uri.getPath()).put("type", type)
                .put("authenticated", valid).put("loopbackPeer", peer.getInetAddress().isLoopbackAddress())
                .put("loopbackHost", hostHeader.equals("127.0.0.1:" + listener.getLocalPort()));
            requests.add(trace);
            int status = valid ? 200 : 403;
            String data = "AAAA".equals(type) || "28".equals(type) ? "2001:db8::10" : "192.0.2.10";
            int rrType = data.contains(":") ? 28 : 1;
            JSONObject body = new JSONObject().put("Status", valid ? 0 : 5)
                .put("Question", new JSONObject().put("name", HOST).put("type", rrType));
            if (valid) body.put("Answer", new JSONArray().put(new JSONObject().put("name", HOST)
                .put("type", rrType).put("TTL", 1).put("data", data)));
            byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
            OutputStream output = peer.getOutputStream();
            output.write(("HTTP/1.1 " + status + " Fixture\r\nContent-Type: application/json\r\nContent-Length: " +
                bytes.length + "\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));
            output.write(bytes);
            output.flush();
        }
    }
}
