const std = @import("std");
const math = std.math;

const Char = i8;
const UChar = u8;
pub const CHAR_INT = @bitSizeOf(Char);
pub const SCHAR_MIN = math.minInt(Char);
pub const SCHAR_MAX = math.maxInt(Char);
pub const UCHAR_MAX = math.maxInt(UChar);
pub const CHAR_MIN = SCHAR_MIN;
pub const CHAR_MAX = SCHAR_MAX;

// maximum number of bytes in a multibyte character, for any supported locale
pub const MB_LEN_MAX = 1;

pub const Short = i16;
pub const UShort = u16;
pub const SHRT_BIT = @bitSizeOf(Short);
pub const SHRT_MIN = math.minInt(Short);
pub const SHRT_MAX = math.maxInt(Short);
pub const USHRT_MAX = math.maxInt(UShort);

pub const Int = i16;
pub const UInt = u16;
pub const INT_BIT = @bitSizeOf(Int);
pub const INT_MIN = math.minInt(Int);
pub const INT_MAX = math.maxInt(Int);
pub const UINT_MAX = math.maxInt(UInt);

pub const Long = i32;
pub const ULong = u32;
pub const LONG_BIT = @bitSizeOf(Long);
pub const LONG_MIN = math.minInt(Long);
pub const LONG_MAX = math.maxInt(Long);
pub const ULONG_MAX = math.maxInt(ULong);

pub const LLong = i64;
pub const ULLong = u64;
pub const LLONG_BIT = @bitSizeOf(LLong);
pub const LLONG_MIN = math.minInt(LLong);
pub const LLONG_MAX = math.maxInt(LLong);
pub const ULLONG_MAX = math.maxInt(ULLong);

pub const Double = f64;

pub fn canFitInInt(v: i64) bool {
    return INT_MIN <= v and v <= INT_MAX;
}

pub fn isSpace(c: u8) bool {
    const vertical_tab = 11;
    const formfeed = 12;
    return switch (c) {
        ' ', '\t', '\n', vertical_tab, formfeed, '\r' => return true,
        else => return false,
    };
}
