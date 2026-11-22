package com.nuoezin.chatroom.ui;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.graphics.Paint;
import android.os.Bundle;
import android.view.View;
import android.widget.Toast;

import androidx.appcompat.app.AlertDialog;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.nuoezin.chatroom.ChatRoomApp;
import com.nuoezin.chatroom.R;
import com.nuoezin.chatroom.net.RoomHost;

public final class MainActivity extends BaseActivity {
    private static final String REPOSITORY = "https://github.com/NuoeZin/ChatRoom";
    private MaterialButton createButton;
    private MaterialButton joinButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        applyInsets(R.id.content, true);

        createButton = findViewById(R.id.createButton);
        joinButton = findViewById(R.id.joinButton);
        createButton.setOnClickListener(view -> showCreateRoomDialog());
        joinButton.setOnClickListener(view -> startActivity(new Intent(this, JoinActivity.class)));
        android.widget.TextView about = findViewById(R.id.aboutLink);
        about.setPaintFlags(about.getPaintFlags() | Paint.UNDERLINE_TEXT_FLAG);
        about.setOnClickListener(view -> showAbout());
    }

    private void showCreateRoomDialog() {
        DialogUtils.textInput(
                this,
                getString(R.string.create_room_title),
                getString(R.string.create_room_prompt),
                getString(R.string.room_name),
                30,
                false,
                this::createRoom
        ).show();
    }

    private void createRoom(String roomName) {
        AlertDialog progress = new MaterialAlertDialogBuilder(this)
                .setMessage(R.string.creating_room)
                .setCancelable(false)
                .create();
        progress.show();
        createButton.setEnabled(false);
        joinButton.setEnabled(false);

        new Thread(() -> {
            try {
                RoomHost host = new RoomHost(roomName);
                host.start();
                runOnUiThread(() -> {
                    progress.dismiss();
                    createButton.setEnabled(true);
                    joinButton.setEnabled(true);
                    if (isFinishing() || isDestroyed()) {
                        host.close();
                        return;
                    }
                    ((ChatRoomApp) getApplication()).setRoomHost(host);
                    startActivity(new Intent(this, HostActivity.class));
                });
            } catch (Exception error) {
                runOnUiThread(() -> {
                    progress.dismiss();
                    createButton.setEnabled(true);
                    joinButton.setEnabled(true);
                    new MaterialAlertDialogBuilder(this)
                            .setTitle(R.string.create_room_title)
                            .setMessage(R.string.create_failed)
                            .setPositiveButton(R.string.close, null)
                            .show();
                });
            }
        }, "chatroom-create-room").start();
    }

    private void showAbout() {
        View content = getLayoutInflater().inflate(R.layout.dialog_about, null);
        AlertDialog dialog = new MaterialAlertDialogBuilder(this)
                .setView(content)
                .setPositiveButton(R.string.close, null)
                .create();
        content.findViewById(R.id.githubButton).setOnClickListener(view -> {
            ClipboardManager clipboard =
                    (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            clipboard.setPrimaryClip(ClipData.newPlainText("GitHub", REPOSITORY));
            Toast.makeText(this, R.string.link_copied, Toast.LENGTH_SHORT).show();
        });
        dialog.show();
        DialogUtils.applyWindow(dialog);
    }
}
