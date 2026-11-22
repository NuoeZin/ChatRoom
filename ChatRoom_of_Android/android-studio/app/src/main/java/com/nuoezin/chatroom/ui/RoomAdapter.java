package com.nuoezin.chatroom.ui;

import android.os.SystemClock;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.nuoezin.chatroom.R;
import com.nuoezin.chatroom.model.RoomInfo;

import java.util.ArrayList;
import java.util.List;

public final class RoomAdapter extends RecyclerView.Adapter<RoomAdapter.Holder> {
    public interface OnRoomClick {
        void onClick(RoomInfo room);
    }

    private final List<RoomInfo> rooms = new ArrayList<>();
    private final OnRoomClick onClick;

    public RoomAdapter(OnRoomClick onClick) {
        this.onClick = onClick;
        setHasStableIds(true);
    }

    public void submit(List<RoomInfo> items) {
        rooms.clear();
        rooms.addAll(items);
        notifyDataSetChanged();
    }

    @Override
    public long getItemId(int position) {
        return rooms.get(position).key().hashCode();
    }

    @NonNull
    @Override
    public Holder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_room, parent, false);
        return new Holder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull Holder holder, int position) {
        RoomInfo room = rooms.get(position);
        TextRules.setText(holder.name, room.name);
        String address = room.address;
        if (room.port != 6510) {
            address += ":" + room.port;
        }
        holder.address.setText(address);
        holder.count.setText(holder.itemView.getContext().getString(R.string.people_count, room.playerCount));
        long seconds = Math.max(0, (SystemClock.elapsedRealtime() - room.lastSeen) / 1000);
        holder.lastSeen.setText(seconds <= 1
                ? holder.itemView.getContext().getString(R.string.just_now)
                : holder.itemView.getContext().getString(R.string.seconds_ago, seconds));
        holder.itemView.setOnClickListener(view -> onClick.onClick(room));
    }

    @Override
    public int getItemCount() {
        return rooms.size();
    }

    static final class Holder extends RecyclerView.ViewHolder {
        final TextView name;
        final TextView address;
        final TextView count;
        final TextView lastSeen;

        Holder(View itemView) {
            super(itemView);
            name = itemView.findViewById(R.id.roomName);
            address = itemView.findViewById(R.id.roomAddress);
            count = itemView.findViewById(R.id.playerCount);
            lastSeen = itemView.findViewById(R.id.lastSeen);
        }
    }
}
