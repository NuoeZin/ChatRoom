package com.nuoezin.chatroom.ui;

import android.content.Context;
import android.text.InputFilter;
import android.view.LayoutInflater;
import android.view.View;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;

import androidx.appcompat.app.AlertDialog;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.textfield.TextInputEditText;
import com.google.android.material.textfield.TextInputLayout;
import com.nuoezin.chatroom.R;

public final class DialogUtils {
    public interface TextAccepted {
        void accept(String text);
    }

    public interface AddressAccepted {
        void accept(String host, int port);
    }

    private DialogUtils() {
    }

    public static AlertDialog textInput(Context context, String title, String prompt,
                                        String hint, int maxLength, boolean allowEmpty,
                                        TextAccepted accepted) {
        View content = LayoutInflater.from(context).inflate(R.layout.dialog_text_input, null);
        TextInputLayout layout = content.findViewById(R.id.inputLayout);
        TextInputEditText edit = content.findViewById(R.id.inputEdit);
        content.findViewById(R.id.promptText).setVisibility(prompt == null ? View.GONE : View.VISIBLE);
        TextRules.setText(
                (android.widget.TextView) content.findViewById(R.id.promptText),
                prompt == null ? "" : prompt
        );
        layout.setHint(hint);
        edit.setFilters(new InputFilter[]{new InputFilter.LengthFilter(maxLength)});
        TextRules.installTree(content);

        AlertDialog dialog = new MaterialAlertDialogBuilder(context)
                .setTitle(title)
                .setView(content)
                .setNegativeButton(R.string.cancel, null)
                .setPositiveButton(R.string.confirm, null)
                .create();
        dialog.setOnShowListener(ignored -> {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(view -> {
                String value = edit.getText() == null ? "" : edit.getText().toString().trim();
                value = TextRules.stripEmoji(value).trim();
                if (!allowEmpty && value.isEmpty()) {
                    layout.setError(context.getString(R.string.required_field));
                    return;
                }
                layout.setError(null);
                dialog.dismiss();
                accepted.accept(value);
            });
            edit.requestFocus();
            dialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE);
            InputMethodManager keyboard =
                    (InputMethodManager) context.getSystemService(Context.INPUT_METHOD_SERVICE);
            keyboard.showSoftInput(edit, InputMethodManager.SHOW_IMPLICIT);
            applyWindow(dialog);
        });
        return dialog;
    }

    public static AlertDialog manualAddress(Context context, AddressAccepted accepted) {
        View content = LayoutInflater.from(context).inflate(R.layout.dialog_manual_join, null);
        TextRules.installTree(content);
        TextInputLayout addressLayout = content.findViewById(R.id.addressLayout);
        TextInputEditText addressEdit = content.findViewById(R.id.addressEdit);

        AlertDialog dialog = new MaterialAlertDialogBuilder(context)
                .setTitle(R.string.manual_title)
                .setView(content)
                .setNegativeButton(R.string.cancel, null)
                .setPositiveButton(R.string.connect, null)
                .create();
        dialog.setOnShowListener(ignored -> {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(view -> {
                String address = addressEdit.getText() == null
                        ? "" : addressEdit.getText().toString().trim();
                ParsedAddress parsed = parseAddress(address);
                addressLayout.setError(parsed.error);
                if (parsed.error != null) {
                    return;
                }
                dialog.dismiss();
                accepted.accept(parsed.host, parsed.port);
            });
            addressEdit.requestFocus();
            dialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE);
            applyWindow(dialog);
        });
        return dialog;
    }

    public static ParsedAddress parseAddress(String input) {
        String text = input == null ? "" : input.trim();
        if (text.isEmpty()) {
            return new ParsedAddress("", 6510, "地址不能为空");
        }
        String host = text;
        int port = 6510;
        int colon = text.lastIndexOf(':');
        if (colon > 0 && text.indexOf(':') == colon) {
            String portText = text.substring(colon + 1);
            try {
                port = Integer.parseInt(portText);
            } catch (NumberFormatException error) {
                return new ParsedAddress("", port, "端口无效（1-65535）");
            }
            if (port <= 0 || port > 65535) {
                return new ParsedAddress("", port, "端口无效（1-65535）");
            }
            host = text.substring(0, colon).trim();
        }
        if (host.isEmpty()) {
            return new ParsedAddress("", port, "地址不能为空");
        }
        return new ParsedAddress(host, port, null);
    }

    public static void applyWindow(AlertDialog dialog) {
        if (dialog.getWindow() != null) {
            dialog.getWindow().setLayout(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.WRAP_CONTENT
            );
        }
    }

    public static final class ParsedAddress {
        public final String host;
        public final int port;
        public final String error;

        ParsedAddress(String host, int port, String error) {
            this.host = host;
            this.port = port;
            this.error = error;
        }
    }
}
