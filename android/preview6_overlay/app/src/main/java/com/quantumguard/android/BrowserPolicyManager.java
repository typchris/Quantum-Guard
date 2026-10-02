package com.quantumguard.android;

import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Bundle;

import org.json.JSONArray;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Managed-browser enforcement for Device Owner / Profile Owner mode.
 * Unsupported keys are ignored by the target browser, so this remains safe across browser versions.
 */
public final class BrowserPolicyManager {
    private static final String CHROME = "com.android.chrome";
    private static final String EDGE = "com.microsoft.emmx";

    private BrowserPolicyManager() {}

    public static void apply(Context c, PolicyStore.Policy p) {
        if (!DeviceController.isManagedOwner(c)) return;
        DevicePolicyManager dpm = c.getSystemService(DevicePolicyManager.class);
        if (dpm == null) return;
        ComponentName admin = DeviceController.admin(c);
        applyOne(c, dpm, admin, CHROME, p, false);
        applyOne(c, dpm, admin, EDGE, p, true);
    }

    private static void applyOne(Context c, DevicePolicyManager dpm, ComponentName admin, String pkg, PolicyStore.Policy p, boolean edge) {
        try { c.getPackageManager().getPackageInfo(pkg, 0); }
        catch (PackageManager.NameNotFoundException e) { return; }

        try {
            Bundle b = new Bundle();

            // Force managed Chromium browsers to use the system resolver when Web Protection is active.
            // This prevents browser Secure DNS from bypassing Quantum Guard's local DNS VPN on supported versions.
            if (p.effectiveWebEnabled()) {
                b.putString("DnsOverHttpsMode", "off");
                b.putBoolean("BuiltInDnsClientEnabled", false);
            }

            String blockJson = jsonArray(normalizeDomains(p.blockedSites));
            String allowJson = jsonArray(normalizeDomains(p.allowedSites));
            b.putString("URLBlocklist", blockJson);
            b.putString("URLAllowlist", allowJson);

            if (p.effectiveDownloadEnabled() && p.blockBrowserDownloads) {
                int restriction = "all".equalsIgnoreCase(p.downloadMode) ? 3 : 2;
                b.putInt("DownloadRestrictions", restriction);
            } else {
                b.putInt("DownloadRestrictions", 0);
            }

            // Edge 147+ can consume this string policy. Older Edge versions simply ignore it.
            if (edge && p.effectiveDownloadEnabled() && !"all".equalsIgnoreCase(p.downloadMode)) {
                List<String> exts = new ArrayList<>();
                for (int i=0;i<p.blockedExtensions.length();i++) {
                    String x = p.blockedExtensions.optString(i, "").trim();
                    while (x.startsWith(".")) x = x.substring(1);
                    if (!x.isEmpty()) exts.add(x);
                }
                if (!exts.isEmpty()) b.putString("DownloadBlockedForFileTypes", jsonArray(exts));
            }

            dpm.setApplicationRestrictions(admin, pkg, b);
        } catch (Exception e) {
            ActivityLog.add(c, "error", "Browser policy failed", pkg + ": " + safe(e));
        }
    }

    private static List<String> normalizeDomains(JSONArray a) {
        List<String> out = new ArrayList<>();
        for (int i=0;i<a.length() && out.size()<900;i++) {
            String d = a.optString(i, "").trim().toLowerCase(Locale.ROOT);
            if (d.startsWith("http://")) d = d.substring(7);
            if (d.startsWith("https://")) d = d.substring(8);
            int slash = d.indexOf('/'); if (slash >= 0) d = d.substring(0, slash);
            while (d.startsWith("*.")) d = d.substring(2);
            if (!d.isEmpty()) out.add(d);
        }
        return out;
    }

    private static String jsonArray(List<String> values) {
        JSONArray a = new JSONArray();
        for (String v : values) a.put(v);
        return a.toString();
    }

    private static String safe(Exception e) {
        String s = e.getMessage();
        return s == null ? e.getClass().getSimpleName() : s;
    }
}
