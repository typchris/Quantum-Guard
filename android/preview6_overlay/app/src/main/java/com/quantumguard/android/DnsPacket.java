package com.quantumguard.android;

import java.util.Arrays;

public final class DnsPacket {
    public final byte[] packet;
    public final int ipHeaderLen;
    public final int srcPort;
    public final int dstPort;
    public final byte[] srcIp;
    public final byte[] dstIp;
    public final byte[] dns;
    public final String qname;

    private DnsPacket(byte[] p, int ihl, int sp, int dp, byte[] sip, byte[] dip, byte[] dnsData, String q) {
        packet=p; ipHeaderLen=ihl; srcPort=sp; dstPort=dp; srcIp=sip; dstIp=dip; dns=dnsData; qname=q;
    }

    public static DnsPacket parse(byte[] p, int len) {
        try {
            if (len < 28 || ((p[0] >> 4) & 0xf) != 4) return null;
            int ihl = (p[0] & 0x0f) * 4;
            if (ihl < 20 || len < ihl + 8 || (p[9] & 0xff) != 17) return null;
            int sp = u16(p, ihl), dp = u16(p, ihl+2);
            if (dp != 53) return null;
            int udpLen = u16(p, ihl+4);
            int dnsLen = Math.min(udpLen - 8, len - ihl - 8);
            if (dnsLen < 12) return null;
            byte[] dns = Arrays.copyOfRange(p, ihl+8, ihl+8+dnsLen);
            String q = readName(dns, 12);
            return new DnsPacket(Arrays.copyOf(p, len), ihl, sp, dp,
                    Arrays.copyOfRange(p,12,16), Arrays.copyOfRange(p,16,20), dns, q);
        } catch (Exception e) { return null; }
    }

    private static int u16(byte[] p, int o) { return ((p[o]&0xff)<<8) | (p[o+1]&0xff); }

    private static String readName(byte[] dns, int pos) {
        StringBuilder b = new StringBuilder();
        int i=pos, guard=0;
        while (i < dns.length && guard++ < 128) {
            int n = dns[i++] & 0xff;
            if (n == 0) break;
            if ((n & 0xc0) != 0 || i+n > dns.length) return "";
            if (b.length()>0) b.append('.');
            for (int k=0;k<n;k++) b.append((char)(dns[i++] & 0xff));
        }
        return b.toString().toLowerCase(java.util.Locale.ROOT);
    }

    public static byte[] nxdomain(byte[] request) {
        byte[] r = Arrays.copyOf(request, request.length);
        if (r.length >= 12) {
            r[2] = (byte)0x81; r[3] = (byte)0x83;
            r[6]=r[7]=r[8]=r[9]=r[10]=r[11]=0;
        }
        return r;
    }

    public byte[] wrapResponse(byte[] dnsResponse) {
        int total = 20 + 8 + dnsResponse.length;
        byte[] out = new byte[total];
        out[0]=0x45; out[1]=0;
        put16(out,2,total); put16(out,4,0); put16(out,6,0x4000);
        out[8]=64; out[9]=17;
        System.arraycopy(dstIp,0,out,12,4); System.arraycopy(srcIp,0,out,16,4);
        put16(out,20,dstPort); put16(out,22,srcPort); put16(out,24,8+dnsResponse.length); put16(out,26,0);
        System.arraycopy(dnsResponse,0,out,28,dnsResponse.length);
        put16(out,10,checksum(out,0,20));
        return out;
    }

    private static void put16(byte[] b,int o,int v){ b[o]=(byte)(v>>>8); b[o+1]=(byte)v; }
    private static int checksum(byte[] b,int off,int len){
        long sum=0;
        for(int i=off;i<off+len;i+=2){ int hi=b[i]&0xff; int lo=(i+1<off+len)?b[i+1]&0xff:0; sum += (hi<<8)|lo; while((sum>>>16)!=0) sum=(sum&0xffff)+(sum>>>16); }
        return (int)(~sum)&0xffff;
    }
}
