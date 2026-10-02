package com.quantumguard.android;

import android.content.Context;
import android.content.res.AssetFileDescriptor;

import java.io.FileInputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.security.MessageDigest;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public final class DomainBlocklist {
    private static final Map<String, DomainBlocklist> CACHE = new HashMap<>();
    private final ByteBuffer data;
    private final int count;
    private final ThreadLocal<MessageDigest> sha = ThreadLocal.withInitial(() -> {
        try { return MessageDigest.getInstance("SHA-256"); } catch (Exception e) { throw new RuntimeException(e); }
    });

    private DomainBlocklist(Context c, String asset) throws Exception {
        AssetFileDescriptor afd = c.getAssets().openFd(asset);
        try (FileInputStream fis = new FileInputStream(afd.getFileDescriptor()); FileChannel ch = fis.getChannel()) {
            MappedByteBuffer mapped = ch.map(FileChannel.MapMode.READ_ONLY, afd.getStartOffset(), afd.getLength());
            mapped.order(ByteOrder.BIG_ENDIAN);
            byte[] magic = new byte[4]; mapped.get(magic);
            if (magic[0] != 'Q' || magic[1] != 'G' || magic[2] != 'H' || magic[3] != '1') throw new IllegalArgumentException("Bad QGH asset");
            count = mapped.getInt();
            data = mapped.asReadOnlyBuffer().order(ByteOrder.BIG_ENDIAN);
        }
        afd.close();
    }

    public static synchronized DomainBlocklist get(Context c, String asset) throws Exception {
        DomainBlocklist b = CACHE.get(asset);
        if (b == null) { b = new DomainBlocklist(c.getApplicationContext(), asset); CACHE.put(asset, b); }
        return b;
    }

    private long hash(String domain) {
        MessageDigest d = sha.get();
        d.reset();
        byte[] h = d.digest(domain.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        return ByteBuffer.wrap(h).order(ByteOrder.BIG_ENDIAN).getLong();
    }

    private boolean containsHash(long target) {
        int low = 0, high = count - 1;
        while (low <= high) {
            int mid = (low + high) >>> 1;
            long v = data.getLong(8 + mid * 8);
            if (v < target) low = mid + 1;
            else if (v > target) high = mid - 1;
            else return true;
        }
        return false;
    }

    public boolean matches(String host) {
        if (host == null) return false;
        String d = host.trim().toLowerCase(Locale.ROOT);
        while (d.endsWith(".")) d = d.substring(0, d.length()-1);
        while (!d.isEmpty()) {
            if (containsHash(hash(d))) return true;
            int dot = d.indexOf('.');
            if (dot < 0) break;
            d = d.substring(dot + 1);
        }
        return false;
    }
}
