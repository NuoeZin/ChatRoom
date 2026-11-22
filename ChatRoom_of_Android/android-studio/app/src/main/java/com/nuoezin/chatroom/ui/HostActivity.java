package com.nuoezin.chatroom.ui;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.TextView;

import androidx.activity.OnBackPressedCallback;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.tabs.TabLayout;
import com.nuoezin.chatroom.ChatRoomApp;
import com.nuoezin.chatroom.R;
import com.nuoezin.chatroom.model.ChatMessage;
import com.nuoezin.chatroom.net.RoomHost;

import java.util.Locale;

public final class HostActivity extends BaseActivity implements RoomHost.Listener {
    private final Handler uptimeHandler = new Handler(Looper.getMainLooper());
    private RoomHost host;
    private MemberAdapter memberAdapter;
    private TextView headerName;
    private TextView cardRoomName;
    private TextView roomId;
    private TextView online;
    private TextView localIp;
    private TextView uptime;
    private TextView memberCount;
    private TextView memberEmpty;
    private RoomHost.Snapshot latest;

    private final Runnable uptimeTick = new Runnable() {
        @Override
        public void run() {
            if (host != null && host.isRunning()) {
                latest = host.snapshot();
                updateSnapshot(latest);
                uptimeHandler.postDelayed(this, 1000);
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_host);
        applyInsets(R.id.content, false);

        host = ((ChatRoomApp) getApplication()).getRoomHost();
        if (host == null || !host.isRunning()) {
            startActivity(new Intent(this, MainActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP));
            finish();
            return;
        }

        headerName = findViewById(R.id.headerRoomName);
        cardRoomName = findViewById(R.id.roomNameText);
        roomId = findViewById(R.id.roomIdText);
        online = findViewById(R.id.onlineText);
        localIp = findViewById(R.id.localIpText);
        uptime = findViewById(R.id.uptimeText);
        memberCount = findViewById(R.id.memberCountText);
        memberEmpty = findViewById(R.id.memberEmpty);

        RecyclerView members = findViewById(R.id.memberList);
        members.setLayoutManager(new LinearLayoutManager(this));
        memberAdapter = new MemberAdapter();
        members.setAdapter(memberAdapter);

        View infoTab = findViewById(R.id.infoTab);
        View membersTab = findViewById(R.id.membersTab);
        TabLayout tabs = findViewById(R.id.roomTabs);
        tabs.addTab(tabs.newTab().setText(R.string.room_info));
        tabs.addTab(tabs.newTab().setText(R.string.room_members));
        tabs.addOnTabSelectedListener(new TabLayout.OnTabSelectedListener() {
            @Override
            public void onTabSelected(TabLayout.Tab tab) {
                boolean showMembers = tab.getPosition() == 1;
                infoTab.setVisibility(showMembers ? View.GONE : View.VISIBLE);
                membersTab.setVisibility(showMembers ? View.VISIBLE : View.GONE);
            }

            @Override
            public void onTabUnselected(TabLayout.Tab tab) {
            }

            @Override
            public void onTabReselected(TabLayout.Tab tab) {
            }
        });

        findViewById(R.id.backButton).setOnClickListener(view -> confirmClose());
        findViewById(R.id.closeRoomButton).setOnClickListener(view -> confirmClose());
        findViewById(R.id.enterChatButton).setOnClickListener(view -> showNicknameDialog());

        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                confirmClose();
            }
        });

        updateSnapshot(host.snapshot());
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (host != null) {
            host.addListener(this);
            uptimeHandler.post(uptimeTick);
        }
    }

    @Override
    protected void onStop() {
        uptimeHandler.removeCallbacks(uptimeTick);
        if (host != null) {
            host.removeListener(this);
        }
        super.onStop();
    }

    @Override
    public void onSnapshot(RoomHost.Snapshot snapshot) {
        latest = snapshot;
        updateSnapshot(snapshot);
    }

    @Override
    public void onMessage(ChatMessage message) {
        // Chat history is consumed by ChatActivity.
    }

    private void updateSnapshot(RoomHost.Snapshot snapshot) {
        if (snapshot == null) {
            return;
        }
        TextRules.setText(headerName, snapshot.roomName);
        TextRules.setText(cardRoomName, snapshot.roomName);
        TextRules.setText(
                roomId,
                getString(R.string.room_id) + "  " + snapshot.roomId
        );
        TextRules.setText(online, getString(R.string.people_count, snapshot.onlineCount()));
        TextRules.setText(memberCount, getString(R.string.people_count, snapshot.onlineCount()));

        StringBuilder addresses = new StringBuilder();
        for (int i = 0; i < snapshot.localAddresses.size(); i++) {
            if (i > 0) {
                addresses.append('\n');
            }
            addresses.append(snapshot.localAddresses.get(i));
        }
        if (addresses.length() == 0) {
            addresses.append("127.0.0.1");
        }
        addresses.append("\n本机: 127.0.0.1:6510");
        TextRules.setText(localIp, addresses);
        TextRules.setText(uptime, formatUptime(snapshot.uptimeMillis));
        memberAdapter.submit(snapshot.members);
        memberEmpty.setVisibility(snapshot.members.isEmpty() ? android.view.View.VISIBLE : android.view.View.GONE);
    }

    private String formatUptime(long millis) {
        long seconds = Math.max(0, millis / 1000);
        long hours = seconds / 3600;
        long minutes = (seconds % 3600) / 60;
        long secs = seconds % 60;
        return String.format(Locale.US, "%02d:%02d:%02d", hours, minutes, secs);
    }

    private void showNicknameDialog() {
        DialogUtils.textInput(
                this,
                getString(R.string.enter_chat),
                getString(R.string.enter_room_hint),
                getString(R.string.nickname),
                15,
                true,
                value -> {
                    String nickname = value.isEmpty()
                            ? getString(R.string.host_nickname) : value;
                    Intent intent = new Intent(this, ChatActivity.class);
                    intent.putExtra(ChatActivity.EXTRA_NICKNAME, nickname);
                    intent.putExtra(ChatActivity.EXTRA_ROOM_NAME, host.getRoomName());
                    intent.putExtra(ChatActivity.EXTRA_ROOM_ID, host.getRoomId());
                    intent.putExtra(ChatActivity.EXTRA_PLAYERS, host.registeredCount());
                    intent.putExtra(ChatActivity.EXTRA_DIRECT_HOST, true);
                    startActivity(intent);
                }
        ).show();
    }

    private void confirmClose() {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.close_room_title)
                .setMessage(R.string.close_room_message)
                .setNegativeButton(R.string.cancel, null)
                .setPositiveButton(R.string.close_room, (dialog, which) -> {
                    ((ChatRoomApp) getApplication()).closeRoomHost();
                    finish();
                })
                .show();
    }
}
