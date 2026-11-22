package com.nuoezin.chatroom.ui;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.nuoezin.chatroom.R;
import com.nuoezin.chatroom.model.Member;

import java.util.ArrayList;
import java.util.List;

public final class MemberAdapter extends RecyclerView.Adapter<MemberAdapter.Holder> {
    private final List<Member> members = new ArrayList<>();

    public void submit(List<Member> items) {
        members.clear();
        members.addAll(items);
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public Holder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_member, parent, false);
        return new Holder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull Holder holder, int position) {
        Member member = members.get(position);
        holder.index.setText("#" + (position + 1));
        TextRules.setText(holder.name, member.name);
        TextRules.setText(holder.address, member.address);
    }

    @Override
    public int getItemCount() {
        return members.size();
    }

    static final class Holder extends RecyclerView.ViewHolder {
        final TextView index;
        final TextView name;
        final TextView address;

        Holder(View itemView) {
            super(itemView);
            index = itemView.findViewById(R.id.memberIndex);
            name = itemView.findViewById(R.id.memberName);
            address = itemView.findViewById(R.id.memberIp);
        }
    }
}
