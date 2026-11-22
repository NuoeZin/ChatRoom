package com.nuoezin.chatroom.ui;

import android.content.Intent;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.TextView;

import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AlertDialog;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.nuoezin.chatroom.ChatRoomApp;
import com.nuoezin.chatroom.R;
import com.nuoezin.chatroom.model.ChatMessage;
import com.nuoezin.chatroom.net.RoomClient;
import com.nuoezin.chatroom.net.RoomHost;

import java.util.List;
import java.util.Locale;

public final class ChatActivity extends BaseActivity implements RoomHost.Listener, RoomClient.Listener {
    public static final String EXTRA_HOST = "host";
    public static final String EXTRA_PORT = "port";
    public static final String EXTRA_NICKNAME = "nickname";
    public static final String EXTRA_ROOM_NAME = "room_name";
    public static final String EXTRA_ROOM_ID = "room_id";
    public static final String EXTRA_PLAYERS = "players";
    public static final String EXTRA_DIRECT_HOST = "direct_host";

    private final long connectedAt = SystemClock.elapsedRealtime();
    private String hostAddress;
    private int hostPort;
    private String nickname;
    private String roomName;
    private String roomId;
    private int online;
    private boolean directHost;
    private boolean connected;
    private boolean disconnectShown;

    private RoomHost roomHost;
    private RoomClient roomClient;
    private MessageAdapter adapter;
    private RecyclerView messageList;
    private LinearLayoutManager layoutManager;
    private EditText input;
    private TextView emptyChat;
    private View progressOverlay;
    private TextView progressText;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_chat);
        applyInsets(R.id.content, false);

        Intent intent = getIntent();
        hostAddress = intent.getStringExtra(EXTRA_HOST);
        hostPort = intent.getIntExtra(EXTRA_PORT, 6510);
        nickname = TextRules.stripEmoji(intent.getStringExtra(EXTRA_NICKNAME));
        roomName = TextRules.stripEmoji(intent.getStringExtra(EXTRA_ROOM_NAME));
        roomId = intent.getStringExtra(EXTRA_ROOM_ID);
        online = Math.max(1, intent.getIntExtra(EXTRA_PLAYERS, 1));
        directHost = intent.getBooleanExtra(EXTRA_DIRECT_HOST, false);
        if (nickname == null || nickname.isEmpty()) {
            nickname = getString(R.string.host_nickname);
        }
        if (roomName == null || roomName.isEmpty()) {
            roomName = getString(R.string.app_name);
        }

        TextRules.setText(
                (TextView) findViewById(R.id.roomTitle),
                roomName + "（" + nickname + "）"
        );
        emptyChat = findViewById(R.id.emptyChat);
        input = findViewById(R.id.messageInput);
        progressOverlay = findViewById(R.id.progressOverlay);
        progressText = findViewById(R.id.progressText);

        messageList = findViewById(R.id.messageList);
        layoutManager = new LinearLayoutManager(this);
        layoutManager.setStackFromEnd(true);
        messageList.setLayoutManager(layoutManager);
        adapter = new MessageAdapter();
        messageList.setAdapter(adapter);

        findViewById(R.id.backButton).setOnClickListener(view -> confirmLeave());
        findViewById(R.id.infoButton).setOnClickListener(view -> showRoomInfo());
        findViewById(R.id.sendButton).setOnClickListener(view -> sendMessage());
        input.setOnEditorActionListener((view, actionId, event) -> {
            boolean enter = event != null
                    && event.getKeyCode() == KeyEvent.KEYCODE_ENTER
                    && event.getAction() == KeyEvent.ACTION_DOWN;
            if (actionId == EditorInfo.IME_ACTION_SEND || enter) {
                sendMessage();
                return true;
            }
            return false;
        });

        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                confirmLeave();
            }
        });

        if (directHost) {
            startDirectHostChat();
        } else {
            startNetworkChat();
        }
    }

    private void startDirectHostChat() {
        roomHost = ((ChatRoomApp) getApplication()).getRoomHost();
        if (roomHost == null || !roomHost.isRunning()) {
            showDisconnected(getString(R.string.room_closed_by_host));
            return;
        }
        roomHost.setHostPresent(true);
        connected = true;
        progressOverlay.setVisibility(View.GONE);
        online = roomHost.registeredCount();

        roomHost.addListener(this);
        List<ChatMessage> history = roomHost.getHistory();
        for (ChatMessage message : history) {
            appendMessage(message);
        }
    }

    private void startNetworkChat() {
        progressOverlay.setVisibility(View.VISIBLE);
        progressText.setText(getString(R.string.connecting) + "\n" + hostAddress + ":" + hostPort);
        roomClient = new RoomClient(
                hostAddress,
                hostPort,
                nickname,
                roomName,
                roomId,
                online,
                this
        );
        roomClient.start();
    }

    private void sendMessage() {
        String text = input.getText() == null ? "" : input.getText().toString().trim();
        text = TextRules.stripEmoji(text).trim();
        if (text.isEmpty()) {
            return;
        }
        if (!connected) {
            return;
        }
        if (directHost) {
            if (roomHost != null && roomHost.isRunning()) {
                roomHost.sendAsHost(nickname, text);
                input.setText("");
            } else {
                showDisconnected(getString(R.string.room_closed_by_host));
            }
        } else if (roomClient != null) {
            if (roomClient.sendMessage(text)) {
                input.setText("");
            }
        }
    }

    private void appendMessage(ChatMessage message) {
        adapter.add(message);
        emptyChat.setVisibility(View.GONE);
        messageList.post(() -> {
            if (adapter.getItemCount() > 0) {
                messageList.scrollToPosition(adapter.getItemCount() - 1);
            }
        });
    }

    @Override
    public void onSnapshot(RoomHost.Snapshot snapshot) {
        if (!directHost) {
            return;
        }
        online = snapshot.onlineCount();
    }

    @Override
    public void onMessage(ChatMessage message) {
        appendMessage(message);
    }

    @Override
    public void onConnected(int initialPlayers) {
        connected = true;
        online = Math.max(initialPlayers, 1);
        progressOverlay.setVisibility(View.GONE);
    }

    @Override
    public void onCountChanged(int online) {
        this.online = Math.max(1, online);
    }

    @Override
    public void onDisconnected(String reason) {
        if (!directHost) {
            showDisconnected(reason);
        }
    }

    private void showDisconnected(String reason) {
        if (disconnectShown || isFinishing()) {
            return;
        }
        disconnectShown = true;
        connected = false;
        progressOverlay.setVisibility(View.GONE);
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.connection_lost)
                .setMessage(reason == null ? getString(R.string.connection_lost_message) : reason)
                .setCancelable(false)
                .setPositiveButton(R.string.action_return, (dialog, which) -> finish())
                .show();
    }

    private void confirmLeave() {
        new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.leave_chat_title)
                .setMessage(R.string.leave_chat_message)
                .setNegativeButton(R.string.keep_chatting, null)
                .setPositiveButton(R.string.leave, (dialog, which) -> finish())
                .show();
    }

    private void showRoomInfo() {
        View content = getLayoutInflater().inflate(R.layout.dialog_room_info, null);
        String displayId = directHost && roomHost != null ? roomHost.getRoomId() : roomId;
        if (displayId == null || displayId.isEmpty()) {
            displayId = hostAddress + ":" + hostPort;
        }
        String server = directHost
                ? "127.0.0.1:6510"
                : hostAddress + ":" + hostPort;
        long seconds = Math.max(0, (SystemClock.elapsedRealtime() - connectedAt) / 1000);
        String duration = String.format(
                Locale.US,
                "%02d:%02d:%02d",
                seconds / 3600,
                (seconds % 3600) / 60,
                seconds % 60
        );

        TextRules.setText((TextView) content.findViewById(R.id.infoName), roomName);
        TextRules.setText((TextView) content.findViewById(R.id.infoRoomId), displayId);
        TextRules.setText((TextView) content.findViewById(R.id.infoServer), server);
        TextRules.setText(
                (TextView) content.findViewById(R.id.infoOnline),
                getString(R.string.people_count, online)
        );
        TextRules.setText((TextView) content.findViewById(R.id.infoNickname), nickname);
        TextRules.setText(
                (TextView) content.findViewById(R.id.infoStatus),
                getString(connected ? R.string.connected : R.string.unresponsive)
        );
        TextRules.setText((TextView) content.findViewById(R.id.infoDuration), duration);

        AlertDialog dialog = new MaterialAlertDialogBuilder(this)
                .setTitle(R.string.room_info)
                .setView(content)
                .setPositiveButton(R.string.close, null)
                .show();
        DialogUtils.applyWindow(dialog);
    }

    @Override
    protected void onDestroy() {
        if (roomHost != null) {
            if (directHost) {
                roomHost.setHostPresent(false);
            }
            roomHost.removeListener(this);
        }
        if (roomClient != null) {
            roomClient.close();
            roomClient = null;
        }
        super.onDestroy();
    }
}
