package com.nuoezin.chatroom.ui;

import android.text.Editable;
import android.text.InputFilter;
import android.text.Selection;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.TextWatcher;
import android.text.style.TypefaceSpan;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.TextView;

import com.nuoezin.chatroom.R;

public final class TextRules {
    private TextRules() {
    }

    public static void installTree(View root) {
        if (root instanceof EditText) {
            installInput((EditText) root);
        }
        if (root instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) root;
            for (int i = 0; i < group.getChildCount(); i++) {
                installTree(group.getChildAt(i));
            }
        }
    }

    public static void installInput(EditText edit) {
        if (edit.getTag(R.id.text_rules_tag) != null) {
            return;
        }
        edit.setTag(R.id.text_rules_tag, Boolean.TRUE);

        InputFilter[] current = edit.getFilters();
        InputFilter[] next = new InputFilter[current.length + 1];
        System.arraycopy(current, 0, next, 0, current.length);
        next[current.length] = new EmojiInputFilter();
        edit.setFilters(next);

        final boolean[] cleaning = {false};
        edit.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence text, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence text, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable editable) {
                if (cleaning[0]) {
                    return;
                }
                String original = editable.toString();
                String cleaned = stripEmoji(original);
                if (!cleaned.equals(original)) {
                    cleaning[0] = true;
                    int selection = Selection.getSelectionEnd(editable);
                    if (selection < 0 || selection > original.length()) {
                        selection = original.length();
                    }
                    int cleanedSelection = stripEmoji(original.substring(0, selection)).length();
                    try {
                        editable.replace(0, editable.length(), cleaned);
                        Selection.setSelection(
                                editable,
                                Math.min(Math.max(0, cleanedSelection), cleaned.length())
                        );
                    } finally {
                        cleaning[0] = false;
                    }
                }
                applySystemFonts(editable);
            }
        });
        applySystemFonts(edit.getText());
    }

    public static void setText(TextView view, CharSequence text) {
        SpannableStringBuilder value = new SpannableStringBuilder(stripEmoji(text == null ? "" : text.toString()));
        applySystemFonts(value);
        view.setText(value, TextView.BufferType.SPANNABLE);
    }

    public static CharSequence display(CharSequence text) {
        SpannableStringBuilder value = new SpannableStringBuilder(stripEmoji(text == null ? "" : text.toString()));
        applySystemFonts(value);
        return value;
    }

    public static void applySystemFonts(Spannable text) {
        if (text == null) {
            return;
        }
        SystemFontSpan[] previous = text.getSpans(0, text.length(), SystemFontSpan.class);
        for (SystemFontSpan span : previous) {
            text.removeSpan(span);
        }

        String value = text.toString();
        int length = value.length();
        int runStart = -1;
        for (int offset = 0; offset < length; ) {
            int codePoint = Character.codePointAt(value, offset);
            int count = Character.charCount(codePoint);
            boolean system = !usesPixelFont(codePoint);
            if (system && runStart < 0) {
                runStart = offset;
            } else if (!system && runStart >= 0) {
                text.setSpan(
                        new SystemFontSpan(),
                        runStart,
                        offset,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                );
                runStart = -1;
            }
            offset += count;
        }
        if (runStart >= 0) {
            text.setSpan(
                    new SystemFontSpan(),
                    runStart,
                    length,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            );
        }
    }

    public static String stripEmoji(String input) {
        if (input == null || input.isEmpty()) {
            return "";
        }
        StringBuilder output = new StringBuilder(input.length());
        for (int offset = 0; offset < input.length(); ) {
            int codePoint = Character.codePointAt(input, offset);
            if (codePoint == 0x20E3) {
                int length = output.length();
                if (length > 0) {
                    int previous = output.codePointBefore(length);
                    if (isEmojiKeycapBase(previous)) {
                        output.delete(length - Character.charCount(previous), length);
                    }
                }
            } else if (!isEmoji(codePoint)) {
                output.appendCodePoint(codePoint);
            }
            offset += Character.charCount(codePoint);
        }
        return output.toString();
    }

    private static boolean usesPixelFont(int codePoint) {
        if (codePoint == '\n' || codePoint == '\r' || codePoint == '\t') {
            return true;
        }
        if (codePoint >= 0x20 && codePoint <= 0x7E) {
            return true;
        }
        if (codePoint >= 0x3000 && codePoint <= 0x303F) {
            return true;
        }
        if (codePoint >= 0x3040 && codePoint <= 0x30FF) {
            return true;
        }
        if (codePoint >= 0x31F0 && codePoint <= 0x31FF) {
            return true;
        }
        if (codePoint >= 0x3400 && codePoint <= 0x9FFF) {
            return true;
        }
        if (codePoint >= 0xF900 && codePoint <= 0xFAFF) {
            return true;
        }
        if (codePoint >= 0xFF00 && codePoint <= 0xFFEF) {
            return true;
        }
        return false;
    }

    private static boolean isEmoji(int codePoint) {
        return (codePoint >= 0x1F000 && codePoint <= 0x1FAFF)
                || (codePoint >= 0x1F1E6 && codePoint <= 0x1F1FF)
                || (codePoint >= 0x2600 && codePoint <= 0x27BF)
                || (codePoint >= 0x2B00 && codePoint <= 0x2BFF)
                || (codePoint >= 0x2300 && codePoint <= 0x23FF)
                || (codePoint >= 0x2934 && codePoint <= 0x2935)
                || (codePoint >= 0xFE00 && codePoint <= 0xFE0F)
                || (codePoint >= 0xE0020 && codePoint <= 0xE007F)
                || codePoint == 0x200D
                || codePoint == 0x00A9
                || codePoint == 0x00AE
                || codePoint == 0x203C
                || codePoint == 0x2049
                || codePoint == 0x2122
                || codePoint == 0x2139
                || codePoint == 0x24C2
                || codePoint == 0x25AA
                || codePoint == 0x25AB
                || codePoint == 0x25B6
                || codePoint == 0x25C0
                || (codePoint >= 0x25FB && codePoint <= 0x25FE)
                || codePoint == 0x3030
                || codePoint == 0x303D
                || codePoint == 0x3297
                || codePoint == 0x3299;
    }

    private static boolean isEmojiKeycapBase(int codePoint) {
        return codePoint == '#'
                || codePoint == '*'
                || (codePoint >= '0' && codePoint <= '9');
    }

    private static final class SystemFontSpan extends TypefaceSpan {
        SystemFontSpan() {
            super("sans-serif");
        }
    }

    private static final class EmojiInputFilter implements InputFilter {
        @Override
        public CharSequence filter(CharSequence source, int start, int end,
                                   Spanned destination, int destinationStart, int destinationEnd) {
            if (source == null) {
                return null;
            }
            CharSequence cleaned = stripEmoji(source.subSequence(start, end).toString());
            return cleaned.length() == end - start ? null : cleaned;
        }
    }
}
