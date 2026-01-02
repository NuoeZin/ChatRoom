/// @function string_limit(str, max_length)
/// @description 限制字符串长度，超出部分用...表示
/// @param str 原始字符串
/// @param max_length 最大长度

function string_limit(str, max_length) {
    if (!is_string(str)) return "";
    
    var str_len = string_length(str);
    if (str_len <= max_length) {
        return str;
    } else {
        return string_copy(str, 1, max_length - 3) + "...";
    }
}