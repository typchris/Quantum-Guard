package com.quantumguard.android;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

public final class SecureStore {
    private static final String PREFS = "quantum_guard_secure";
    private static final String KEY_ALIAS = "QuantumGuardAndroidSession";
    private final SharedPreferences prefs;

    public SecureStore(Context context) {
        prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private SecretKey key() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore");
        ks.load(null);
        if (!ks.containsAlias(KEY_ALIAS)) {
            KeyGenerator kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            kg.init(new KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build());
            kg.generateKey();
        }
        return ((KeyStore.SecretKeyEntry) ks.getEntry(KEY_ALIAS, null)).getSecretKey();
    }

    public void putSecret(String name, String value) {
        try {
            if (value == null || value.isEmpty()) {
                prefs.edit().remove(name).apply();
                return;
            }
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.ENCRYPT_MODE, key());
            byte[] enc = c.doFinal(value.getBytes(StandardCharsets.UTF_8));
            byte[] iv = c.getIV();
            byte[] packed = new byte[1 + iv.length + enc.length];
            packed[0] = (byte) iv.length;
            System.arraycopy(iv, 0, packed, 1, iv.length);
            System.arraycopy(enc, 0, packed, 1 + iv.length, enc.length);
            prefs.edit().putString(name, Base64.encodeToString(packed, Base64.NO_WRAP)).apply();
        } catch (Exception e) {
            throw new IllegalStateException("Secure storage failed", e);
        }
    }

    public String getSecret(String name) {
        try {
            String raw = prefs.getString(name, "");
            if (raw == null || raw.isEmpty()) return "";
            byte[] packed = Base64.decode(raw, Base64.NO_WRAP);
            int ivLen = packed[0] & 0xff;
            byte[] iv = new byte[ivLen];
            byte[] enc = new byte[packed.length - 1 - ivLen];
            System.arraycopy(packed, 1, iv, 0, ivLen);
            System.arraycopy(packed, 1 + ivLen, enc, 0, enc.length);
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, iv));
            return new String(c.doFinal(enc), StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "";
        }
    }

    public void put(String name, String value) { prefs.edit().putString(name, value == null ? "" : value).apply(); }
    public String get(String name) { return prefs.getString(name, ""); }
    public void putLong(String name, long value) { prefs.edit().putLong(name, value).apply(); }
    public long getLong(String name, long def) { return prefs.getLong(name, def); }
    public void putBoolean(String name, boolean value) { prefs.edit().putBoolean(name, value).apply(); }
    public boolean getBoolean(String name, boolean def) { return prefs.getBoolean(name, def); }

    public void clearSession() {
        putSecret("access_token", "");
        putSecret("refresh_token", "");
        prefs.edit().remove("device_id").remove("selected_device_id").apply();
    }
}
