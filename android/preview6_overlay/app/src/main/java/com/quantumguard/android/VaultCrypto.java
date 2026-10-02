package com.quantumguard.android;

import android.content.Context;
import android.net.Uri;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.SecureRandom;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;

public final class VaultCrypto {
    private VaultCrypto() {}
    private static SecretKey derive(char[] password,byte[] salt) throws Exception{
        PBEKeySpec spec=new PBEKeySpec(password,salt,210000,256);
        byte[] key=SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
        spec.clearPassword(); return new SecretKeySpec(key,"AES");
    }

    public static File encryptToVault(Context c, Uri source, String displayName, char[] password) throws Exception{
        if(password==null||password.length<8)throw new IllegalArgumentException("Vault password must be at least 8 characters");
        byte[] salt=new byte[16],iv=new byte[12]; SecureRandom r=new SecureRandom(); r.nextBytes(salt);r.nextBytes(iv);
        Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE,derive(password,salt),new GCMParameterSpec(128,iv));
        File dir=new File(c.getFilesDir(),"vault"); if(!dir.exists()&&!dir.mkdirs())throw new Exception("Unable to create Vault");
        String safe=(displayName==null?"item":displayName).replaceAll("[^A-Za-z0-9._-]","_");
        File outFile=new File(dir,System.currentTimeMillis()+"-"+safe+".qgvault");
        try(InputStream in=c.getContentResolver().openInputStream(source); FileOutputStream raw=new FileOutputStream(outFile)){
            raw.write(new byte[]{'Q','G','V','1'});raw.write(salt);raw.write(iv);
            javax.crypto.CipherOutputStream out=new javax.crypto.CipherOutputStream(raw,cipher);
            byte[] b=new byte[65536];int n;while((n=in.read(b))>0)out.write(b,0,n);out.close();
        }
        return outFile;
    }

    public static void decryptFromVault(File source, OutputStream destination, char[] password) throws Exception{
        try(FileInputStream raw=new FileInputStream(source)){
            byte[] magic=new byte[4]; if(raw.read(magic)!=4||magic[0]!='Q'||magic[1]!='G'||magic[2]!='V'||magic[3]!='1')throw new Exception("Not a Quantum Guard Vault file");
            byte[] salt=new byte[16],iv=new byte[12]; if(raw.read(salt)!=16||raw.read(iv)!=12)throw new Exception("Vault file is incomplete");
            Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,derive(password,salt),new GCMParameterSpec(128,iv));
            javax.crypto.CipherInputStream in=new javax.crypto.CipherInputStream(raw,cipher);
            byte[] b=new byte[65536];int n;while((n=in.read(b))>0)destination.write(b,0,n);destination.flush();
        }
    }
}
