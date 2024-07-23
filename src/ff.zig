const std = @import("std");
const expect = std.testing.expect;

pub fn IntMod(comptime T: type, comptime n: T) type {
    return struct {
        order: T,
        val: T,

        pub fn init(v: anytype) IntMod(T, n) {
            return IntMod(T, n){ .order = n, .val = @mod(v, @as(@TypeOf(v), n)) };
        }

        pub const p = IntMod(T, n).init(n);

        // pick a scalar uniformly-random from [1,n)
        pub fn roll() IntMod(T, n) {
            const rng = std.crypto.random;
            const max_t = std.math.IntFittingRange(-1, n);
            const max = std.math.maxInt(max_t);
            while (true) {
                const v = rng.int(max_t);
                const cand = IntMod(T, n).init(v);
                if (cand.val != 0 and v < (max - @mod(max, n))) {
                    return cand;
                }
            }
        }

        // Eq
        pub fn eq(self: IntMod(T, n), other: IntMod(T, n)) bool {
            return self.val == other.val;
        }

        pub fn ne(self: IntMod(T, n), other: IntMod(T, n)) bool {
            return !self.eq(other);
        }

        // Num
        pub fn plus(self: IntMod(T, n), other: IntMod(T, n)) IntMod(T, n) {
            return IntMod(T, n).init(self.val + other.val);
        }

        pub fn minus(self: IntMod(T, n), other: IntMod(T, n)) IntMod(T, n) {
            return IntMod(T, n).init(self.val - other.val);
        }

        pub fn times(self: IntMod(T, n), other: IntMod(T, n)) IntMod(T, n) {
            return IntMod(T, n).init(self.val * other.val);
        }

        pub fn neg(self: IntMod(T, n)) IntMod(T, n) {
            return p.minus(self);
        }

        pub fn over(self: IntMod(T, n), other: IntMod(T, n)) !IntMod(T, n) {
            if (powmod(T, other.val, self.order - 2, self.order)) |r| {
                return self.times(IntMod(T, n).init(r));
            } else |err| {
                return err;
            }
        }

        pub fn squared(self: IntMod(T, n)) IntMod(T, n) {
            return self.times(self);
        }

        pub fn raised_to(self: IntMod(T, n), pow: T) !IntMod(T, n) {
            if (powmod(T, self.val, pow, n)) |r| {
                return IntMod(T, n).init(r);
            } else |err| {
                return err;
            }
        }

        pub fn sqrt(self: IntMod(T, n)) !IntMod(T, n) {
            if (!is_quadratic_residue(self.val)) {
                return error.NonResidue;
            }

            const qs = getQS();
            if (qs.s == 1) {
                return IntMod(T, n).init(
                    try powmod(T, self.val, (n + 1) >> 2, n)
                );
            }

            var z: T = 2;
            while ((try powmod(T, z, (n - 1) >> 1, n)) != n - 1) : (z += 1) {}

            var m = qs.s;
            var c = try powmod(T, z, qs.q, n);
            var t = try powmod(T, self.val, qs.q, n);
            const r_pow = (qs.q + 1) >> 1;
            var r = try powmod(T, self.val, r_pow, n);

            while (true) {
                if (t == 1) { return IntMod(T, n).init(r); }

                var zz: T = t;
                var i: T = 0;
                while (zz != 1 and i < (m - 1)) : (i += 1) {
                    zz = @mod(zz * zz, n);
                }

                var e: T = m - i - 1;
                var b = c;
                while (e > 0) : (e -= 1) {
                    b = @mod(b * b, n);
                }

                r = @mod(r * b, n);
                c = @mod(b * b, n);
                t = @mod(t * c, n);
                m = i;
            }
        }

        pub fn getQS() struct { q: T, s: T } {
            const order_less_one = n - 1;
            var S: T = 0;
            var Q: T = order_less_one;
            while (@mod(Q, 2) != 1) {
                S += 1;
                Q >>= 1;
            }

            return .{ .q = Q, .s = S };
        }

        pub fn is_quadratic_residue(cand: T) bool {
            const order_less_one = n - 1;
            const pow = order_less_one >> 1;
            if (powmod(T, cand, pow, n)) |r| {
                return r == 1;
            } else |_| {
                return false;
            }
        }

        // Show
        pub fn format(
            self: IntMod(T, n),
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype
        ) !void {
            _ = fmt;
            _ = options;

            try writer.print("{} % {}", .{self.val, self.order});
        }
    };
}

fn powmod(comptime T: type, base: T, exp: T, mod: T) !T {
    var r: T = 1;
    var b: T = @mod(base, mod);
    var e: T = exp;
    if (b == 0) return 0;
    while (e > 0) : (e >>= 1) {
        if (@mod(e, 2) == 1) r = @mod(r * b, mod);
        b = @mod(b * b, mod);
    }

    return r;
}

pub const F7 = IntMod(i128, 7);
pub const F1009 = IntMod(i128, 1009);

const talloc = std.testing.allocator;

test "finite field addition" {
    const a_cases = [_]i128{ 0, 1, 2, 3, 4, 5, 6 };
    const b_cases = [_]i128{ 0, 1, 2, 3, 4, 5, 6 };
    for (a_cases) |a| {
        for (b_cases) |b| {
            const x = F7.init(a);
            const y = F7.init(b);
            try expect((x.plus(y)).val == @mod(a + b, 7));
        }
    }
}

test "finite field subtraction" {
    const a_cases = [_]i128{ 0, 1, 2, 3, 4, 5, 6 };
    const b_cases = [_]i128{ 0, 1, 2, 3, 4, 5, 6 };
    for (a_cases) |a| {
        for (b_cases) |b| {
            const x = F7.init(a);
            const y = F7.init(b);
            try expect((x.minus(y)).val == @mod(a - b, 7));
        }
    }
}

test "finite field multiplication" {
    const a_cases = [_]i128{ 0, 1, 2, 3, 4, 5, 6 };
    const b_cases = [_]i128{ 0, 1, 2, 3, 4, 5, 6 };
    for (a_cases) |a| {
        for (b_cases) |b| {
            const x = F7.init(a);
            const y = F7.init(b);
            try expect((x.times(y)).val == @mod(a * b, 7));
        }
    }
}

test "finite field division" {
    const a = F7.init(1);
    try expect((try a.over(F7.init(1))).eq(F7.init(1)));
    try expect((try a.over(F7.init(2))).eq(F7.init(4)));
    try expect((try a.over(F7.init(3))).eq(F7.init(5)));
    try expect((try a.over(F7.init(4))).eq(F7.init(2)));
    try expect((try a.over(F7.init(5))).eq(F7.init(3)));
    try expect((try a.over(F7.init(6))).eq(F7.init(6)));
}

test "finite field sqrt (tonelli-shanks)" {
    const F13 = IntMod(i16, 13);
    if ((F13.init(10)).sqrt()) |r1| {
        const r2 = r1.neg();
        try expect(r1.eq(F13.init(7)));
        try expect(r2.eq(F13.init(6)));
    } else |_| {
        try expect(false);
    }

    const F101 = IntMod(i32, 101);
    if ((F101.init(56)).sqrt()) |r1| {
        const r2 = r1.neg();
        try expect(r1.eq(F101.init(37)));
        try expect(r2.eq(F101.init(64)));
    } else |_| {
        try expect(false);
    }

    const F10009 = IntMod(i64, 10009);
    if ((F10009.init(1030)).sqrt()) |r1| {
        const r2 = r1.neg();
        try expect(r1.eq(F10009.init(1632)));
        try expect(r2.eq(F10009.init(8377)));
    } else |_| {
        try expect(false);
    }

    if ((F10009.init(1032)).sqrt()) |_| {
        try expect(false);
    } else |_| {
        try expect(true);
    }

    const F100049 = IntMod(i64, 100049);
    if ((F100049.init(44402)).sqrt()) |r1| {
        const r2 = r1.neg();
        try expect(r1.eq(F100049.init(30468)));
        try expect(r2.eq(F100049.init(69581)));
    } else |_| {
        try expect(false);
    }
}

test "finite field {in,}equality" {
    try expect(F7.init(7).eq(F7.init(0)));
    try expect(F7.init(10).eq(F7.init(3)));
    try expect(F7.init(-3).eq(F7.init(4)));
    try expect(F7.init(0).ne(F7.init(1)));
    try expect(F7.init(0).ne(F7.init(2)));
    try expect(F7.init(1).ne(F7.init(2)));
}

test "F1009 once-over" {
    try expect((F1009.init(-1)).eq(F1009.init(1008)));
    try expect((F1009.init(6)).ne(F1009.init(5)));
    const ooo = F1009.init(101);
    const onek = F1009.init(1000);
    try expect(ooo.plus(onek).eq(F1009.init(92)));
    try expect(ooo.minus(onek).eq(F1009.init(110)));
    try expect(ooo.times(onek).eq(F1009.init(100)));
    try expect((try ooo.over(onek)).eq(F1009.init(213)));
}

test "finite field formatting" {
    const n = F1009.init(-1);
    const s = try std.fmt.allocPrint(talloc, "{}", .{n});
    defer talloc.free(s);

    try expect(std.mem.eql(u8, s, "1008 % 1009"));
}

test "rolling finite field elements" {
    for (1..10000) |_| {
        const f = F1009.roll();
        try expect(f.val > 0 and f.val < f.order);
    }
}
