package com.quantumguard.android;

import android.app.Service;
import android.app.admin.DevicePolicyManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;

public final class CloudSyncService extends Service {
    private ScheduledExecutorService exec;
    private final AtomicBoolean syncing=new AtomicBoolean(false);
    private SupabaseApi api;
    private WebSocket realtime;
    private long realtimeRef=1;
    private int reconnectFailures=0;
    private BroadcastReceiver packageReceiver;

    public static void start(Context c){
        Intent i=new Intent(c,CloudSyncService.class);
        if(Build.VERSION.SDK_INT>=26)c.startForegroundService(i);else c.startService(i);
    }

    @Override public void onCreate(){
        super.onCreate();api=SupabaseApi.get(this);exec=Executors.newScheduledThreadPool(3);registerPackageWatcher();
    }

    @Override public int onStartCommand(Intent intent,int flags,int startId){
        startForeground(2101,NotificationUtil.ongoing(this,"Quantum Guard","Managed-device protection is active"));
        if(!api.signedIn()||api.store().get("device_id").isEmpty()){stopSelf();return START_NOT_STICKY;}
        exec.execute(this::syncNow);
        exec.execute(this::publishApps); // Publish immediately so App Blocker inventory is available on first open.
        exec.scheduleAtFixedRate(this::heartbeat,1,10,TimeUnit.MINUTES);
        exec.scheduleAtFixedRate(this::syncNow,2,15,TimeUnit.MINUTES);
        exec.scheduleAtFixedRate(this::enforce,10,30,TimeUnit.SECONDS);
        exec.scheduleAtFixedRate(this::publishApps,30,30,TimeUnit.MINUTES);
        exec.execute(this::connectRealtime);
        return START_STICKY;
    }

    private void registerPackageWatcher(){
        packageReceiver=new BroadcastReceiver(){@Override public void onReceive(Context c,Intent i){if(exec!=null&&!exec.isShutdown())exec.schedule(CloudSyncService.this::publishApps,2,TimeUnit.SECONDS);}};
        IntentFilter f=new IntentFilter();
        f.addAction(Intent.ACTION_PACKAGE_ADDED);f.addAction(Intent.ACTION_PACKAGE_REMOVED);f.addAction(Intent.ACTION_PACKAGE_REPLACED);f.addDataScheme("package");
        if(Build.VERSION.SDK_INT>=33)registerReceiver(packageReceiver,f,Context.RECEIVER_EXPORTED);else registerReceiver(packageReceiver,f);
    }

    private void heartbeat(){
        try{api.heartbeat(api.store().get("device_id"));reconnectFailures=0;}catch(Exception e){Log.w("QuantumGuard","heartbeat",e);}
    }

    private void publishApps(){
        try{
            String id=api.store().get("device_id");if(id.isEmpty())return;
            JSONArray apps=DeviceController.installedApps(this);
            api.replaceDeviceApps(id,apps);
            api.store().putLong("last_app_publish",System.currentTimeMillis());
            api.store().putLong("last_app_count",apps.length());
        }catch(Exception e){Log.w("QuantumGuard","inventory",e);api.store().put("inventory_last_error",safe(e));}
    }

    private void syncNow(){
        if(!syncing.compareAndSet(false,true))return;
        try{
            String id=api.store().get("device_id"); if(id.isEmpty())return;
            JSONObject ctx=api.deviceContext(id);
            JSONObject policy=ctx.optJSONObject("policy_settings");
            if(policy!=null)new PolicyStore(this).save(policy);
            JSONArray cmds=api.pendingCommands(id);
            for(int i=0;i<cmds.length();i++)processCommand(cmds.optJSONObject(i));
            enforce();
            reconnectFailures=0;
        }catch(Exception e){Log.w("QuantumGuard","sync",e);api.store().put("sync_last_error",safe(e));}finally{syncing.set(false);}
    }

    private void processCommand(JSONObject c){
        if(c==null)return;String id=c.optString("id","");String type=c.optString("command_type","");
        try{
            PolicyStore ps=new PolicyStore(this);JSONObject p=ps.raw();
            switch(type){
                case "refresh_policy": break;
                case "refresh_app_inventory": publishApps();break;
                case "start_focus": p.put("focus_mode",true);ps.save(p);break;
                case "stop_focus": p.put("focus_mode",false);ps.save(p);break;
                case "enable_web_protection": p.put("web_protection_enabled",true);ps.save(p);break;
                case "disable_web_protection": p.put("web_protection_enabled",false);ps.save(p);break;
                case "enable_download_guard": p.put("download_guard_enabled",true);ps.save(p);break;
                case "disable_download_guard": p.put("download_guard_enabled",false);ps.save(p);break;
                case "lock_all_apps": p.put("focus_mode",true).put("focus_policy","allow").put("focus_allowed",new JSONArray());ps.save(p);break;
                case "lock_device":
                case "sign_out_user":
                    DevicePolicyManager dpm=getSystemService(DevicePolicyManager.class);
                    if(dpm!=null&&DeviceController.isManagedOwner(this))dpm.lockNow();
                    break;
                default: break;
            }
            enforce(); api.ackCommand(id,"completed",new JSONObject().put("platform","android").put("handled",true));
            ActivityLog.add(this,"cloud","Remote command",type);
        }catch(Exception e){try{api.ackCommand(id,"failed",new JSONObject().put("error",safe(e)));}catch(Exception ignored){}}
    }

    private void enforce(){
        PolicyStore.Policy p=new PolicyStore(this).get();
        DeviceController.applyManagedPolicy(this,p);
        WebProtectionVpnService.ensure(this,p.effectiveWebEnabled());
        DownloadGuardService.ensure(this,p.effectiveDownloadEnabled());
    }

    private void connectRealtime(){
        try{
            String id=api.store().get("device_id"),token=api.accessToken();if(id.isEmpty())return;
            String base=BuildConfig.SUPABASE_URL.replace("https://","wss://").replace("http://","ws://");
            String url=base+"/realtime/v1/websocket?apikey="+BuildConfig.SUPABASE_PUBLISHABLE_KEY+"&vsn=1.0.0";
            Request req=new Request.Builder().url(url).build();
            realtime=api.http().newWebSocket(req,new WebSocketListener(){
                @Override public void onOpen(WebSocket ws,Response response){reconnectFailures=0;joinRealtime(ws,id,token);}
                @Override public void onMessage(WebSocket ws,String text){if(text.contains("postgres_changes")||text.contains("device_commands")||text.contains("device_policy_assignments"))exec.execute(CloudSyncService.this::syncNow);}
                @Override public void onFailure(WebSocket ws,Throwable t,Response response){scheduleReconnect();}
                @Override public void onClosed(WebSocket ws,int code,String reason){scheduleReconnect();}
            });
            exec.scheduleAtFixedRate(()->{try{if(realtime!=null)realtime.send(new JSONObject().put("topic","phoenix").put("event","heartbeat").put("payload",new JSONObject()).put("ref",String.valueOf(realtimeRef++)).toString());}catch(Exception ignored){}},25,25,TimeUnit.SECONDS);
        }catch(Exception e){scheduleReconnect();}
    }

    private void joinRealtime(WebSocket ws,String id,String token){
        try{
            JSONArray changes=new JSONArray()
                    .put(new JSONObject().put("event","*").put("schema","public").put("table","device_commands").put("filter","device_id=eq."+id))
                    .put(new JSONObject().put("event","*").put("schema","public").put("table","device_policy_assignments").put("filter","device_id=eq."+id));
            JSONObject cfg=new JSONObject().put("broadcast",new JSONObject().put("ack",false).put("self",false)).put("presence",new JSONObject().put("enabled",false)).put("postgres_changes",changes);
            JSONObject payload=new JSONObject().put("config",cfg).put("access_token",token);
            JSONObject join=new JSONObject().put("topic","realtime:qg-device-"+id).put("event","phx_join").put("payload",payload).put("ref",String.valueOf(realtimeRef++));
            ws.send(join.toString());
        }catch(Exception ignored){}
    }

    private void scheduleReconnect(){
        if(exec==null||exec.isShutdown())return;
        int n=Math.min(reconnectFailures++,6); long delay=Math.min(300,5L*(1L<<n));
        exec.schedule(this::connectRealtime,delay,TimeUnit.SECONDS);
    }

    @Override public void onDestroy(){
        if(realtime!=null)realtime.close(1000,"service stopped");
        if(packageReceiver!=null)try{unregisterReceiver(packageReceiver);}catch(Exception ignored){}
        if(exec!=null)exec.shutdownNow();
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent){return null;}
    private static String safe(Exception e){String s=e.getMessage();return s==null?e.getClass().getSimpleName():s;}
}
