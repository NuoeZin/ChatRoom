package com.nuoezin.chatroom.ui;

import android.content.Intent;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;

import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.nuoezin.chatroom.R;
import com.nuoezin.chatroom.model.RoomInfo;
import com.nuoezin.chatroom.net.NetworkUtils;
import com.nuoezin.chatroom.net.RoomDiscovery;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.List;

public final class JoinActivity extends BaseActivity {
    private RoomDiscovery discovery;
    private RoomAdapter adapter;
    private View emptyState;
    private TextView roomCount;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_join);
        applyInsets(R.id.content, false);

        emptyState = findViewById(R.id.emptyState);
        roomCount = findViewById(R.id.roomCount);
        roomCount.setText(getString(R.string.found_rooms, 0));
        RecyclerView list = findViewById(R.id.roomList);
        list.setLayoutManager(new LinearLayoutManager(this));
        adapter = new RoomAdapter(this::openRoom);
        list.setAdapter(adapter);

        findViewById(R.id.backButton).setOnClickListener(view -> finish());
        findViewById(R.id.refreshButton).setOnClickListener(view -> restartDiscovery());
        findViewById(R.id.manualButton).setOnClickListener(view -> showManualDialog());
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (discovery == null) {
            discovery = new RoomDiscovery(this, this::showRooms);
            discovery.start();
        }
    }

    @Override
    protected void onStop() {
        stopDiscovery();
        super.onStop();
    }

    private void restartDiscovery() {
        stopDiscovery();
        adapter.submit(java.util.Collections.emptyList());
        emptyState.setVisibility(View.VISIBLE);
        roomCount.setText(getString(R.string.found_rooms, 0));
        discovery = new RoomDiscovery(this, this::showRooms);
        discovery.start();
        Toast.makeText(this, R.string.refreshed, Toast.LENGTH_SHORT).show();
    }

    private void stopDiscovery() {
        if (discovery != null) {
            discovery.close();
            discovery = null;
        }
    }

    private void showRooms(List<RoomInfo> rooms) {
        adapter.submit(rooms);
        boolean empty = rooms.isEmpty();
        emptyState.setVisibility(empty ? View.VISIBLE : View.GONE);
        roomCount.setText(getString(R.string.found_rooms, rooms.size()));
    }

    private void openRoom(RoomInfo room) {
        if (SystemClock.elapsedRealtime() - room.lastSeen > 12000) {
            Toast.makeText(this, R.string.unavailable_room, Toast.LENGTH_SHORT).show();
            return;
        }
        DialogUtils.textInput(
                this,
                getString(R.string.join_room_title),
                room.name + "\n" + room.address + ":" + room.port,
                getString(R.string.nickname),
                15,
                false,
                nickname -> startChat(room.address, room.port, nickname, room.name,
                        room.roomId, room.playerCount, false)
        ).show();
    }

    private void showManualDialog() {
        DialogUtils.manualAddress(this, this::checkManualService).show();
    }

    private void checkManualService(String host, int port) {
        String targetHost = NetworkUtils.effectiveHost(host);
        View overlay = findViewById(R.id.progressOverlay);
        TextView progress = findViewById(R.id.progressText);
        progress.setText(getString(R.string.connecting) + "\n" + targetHost + ":" + port);
        overlay.setVisibility(View.VISIBLE);

        new Thread(() -> {
            boolean reachable;
            try (Socket socket = new Socket()) {
                socket.connect(new InetSocketAddress(targetHost, port), 3000);
                reachable = true;
            } catch (IOException error) {
                reachable = false;
            }
            final boolean reachableResult = reachable;

            runOnUiThread(() -> {
                if (isFinishing() || isDestroyed()) {
                    return;
                }
                overlay.setVisibility(View.GONE);
                if (reachableResult) {
                    DialogUtils.textInput(
                            this,
                            getString(R.string.join_room_title),
                            targetHost + ":" + port,
                            getString(R.string.nickname),
                            15,
                            false,
                            nickname -> startChat(targetHost, port, nickname,
                                    getString(R.string.manual_room), "", 0, false)
                    ).show();
                } else {
                    new MaterialAlertDialogBuilder(this)
                            .setTitle(R.string.manual_title)
                            .setMessage(R.string.manual_check_failed)
                            .setPositiveButton(R.string.close, null)
                            .show();
                }
            });
        }, "chatroom-manual-check").start();
    }

    private void startChat(String host, int port, String nickname, String roomName,
                           String roomId, int players, boolean directHost) {
        Intent intent = new Intent(this, ChatActivity.class);
        intent.putExtra(ChatActivity.EXTRA_HOST, host);
        intent.putExtra(ChatActivity.EXTRA_PORT, port);
        intent.putExtra(ChatActivity.EXTRA_NICKNAME, nickname);
        intent.putExtra(ChatActivity.EXTRA_ROOM_NAME, roomName);
        intent.putExtra(ChatActivity.EXTRA_ROOM_ID, roomId);
        intent.putExtra(ChatActivity.EXTRA_PLAYERS, players);
        intent.putExtra(ChatActivity.EXTRA_DIRECT_HOST, directHost);
        startActivity(intent);
    }
}
