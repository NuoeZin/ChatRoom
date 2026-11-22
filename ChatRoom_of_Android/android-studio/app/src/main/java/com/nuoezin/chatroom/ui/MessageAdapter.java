package com.nuoezin.chatroom.ui;

import android.graphics.Color;
import android.text.SpannableStringBuilder;
import android.text.style.ForegroundColorSpan;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.nuoezin.chatroom.R;
import com.nuoezin.chatroom.model.ChatMessage;

import java.util.ArrayList;
import java.util.List;

public final class MessageAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private static final int TYPE_SYSTEM = 0;
    private static final int TYPE_CHAT = 1;
    private final List<ChatMessage> items = new ArrayList<>();

    public void clear() {
        items.clear();
        notifyDataSetChanged();
    }

    public void add(ChatMessage message) {
        items.add(message);
        if (items.size() > 200) {
            items.remove(0);
            notifyItemRemoved(0);
        }
        notifyItemInserted(items.size() - 1);
    }

    @Override
    public int getItemViewType(int position) {
        switch (items.get(position).type) {
            case SYSTEM:
                return TYPE_SYSTEM;
            default:
                return TYPE_CHAT;
        }
    }

    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        LayoutInflater inflater = LayoutInflater.from(parent.getContext());
        if (viewType == TYPE_SYSTEM) {
            return new SystemHolder(inflater.inflate(R.layout.item_message_system, parent, false));
        }
        return new ChatHolder(inflater.inflate(R.layout.item_message_text, parent, false));
    }

    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        ChatMessage message = items.get(position);
        if (holder instanceof SystemHolder) {
            TextRules.setText(((SystemHolder) holder).text, message.text);
        } else if (holder instanceof ChatHolder) {
            ChatHolder chat = (ChatHolder) holder;
            String sender = TextRules.stripEmoji(
                    message.sender.isEmpty() ? "访客" : message.sender
            );
            String prefix = sender + ": ";
            SpannableStringBuilder line = new SpannableStringBuilder(prefix);
            line.setSpan(
                    new ForegroundColorSpan(Color.rgb(180, 200, 220)),
                    0,
                    prefix.length(),
                    SpannableStringBuilder.SPAN_EXCLUSIVE_EXCLUSIVE
            );
            line.append(TextRules.stripEmoji(message.text));
            TextRules.applySystemFonts(line);
            chat.text.setText(line, TextView.BufferType.SPANNABLE);
        }
    }

    @Override
    public int getItemCount() {
        return items.size();
    }

    static final class SystemHolder extends RecyclerView.ViewHolder {
        final TextView text;

        SystemHolder(View itemView) {
            super(itemView);
            text = itemView.findViewById(R.id.messageText);
        }
    }

    static final class ChatHolder extends RecyclerView.ViewHolder {
        final TextView text;

        ChatHolder(View itemView) {
            super(itemView);
            text = itemView.findViewById(R.id.messageText);
        }
    }
}
