const std = @import("std");
const expect = std.testing.expect;

const ff = @import("./ff.zig");

fn Pair(comptime T: type) type {
    return struct {
        x: T,
        y: T,
    };
}

fn ModClkPt(comptime T: type, comptime n: T) type {
    const FT = ff.IntMod(T, n);
    return struct {
        coords: Pair(FT),

        pub fn at(x: FT, y: FT) ModClkPt(T, n) {
            return ModClkPt(T, n){
                .coords = .{ .x = x, .y = y },
            };
        }

        pub fn from_x(x: FT, positive: bool) !ModClkPt(T, n) {
            const onelessxsq = (FT.init(1)).minus(x.squared());
            if (onelessxsq.sqrt()) |y| {
                const cand = ModClkPt(T, n).at(x, y);
                if (cand.is_valid()) {
                    return if (positive) cand else cand.reflected();
                } else {
                    return error.NotOnCurve;
                }
            } else |err| {
                return err;
            }
        }

        pub fn is_valid(self: ModClkPt(T, n)) bool {
            const xsq = self.coords.x.squared();
            const ysq = self.coords.y.squared();
            const r = xsq.plus(ysq);
            return r.val == 1;
        }

        pub const zero = ModClkPt(T, n).at(FT.init(0), FT.init(1));

        pub fn reflected(self: ModClkPt(T, n)) ModClkPt(T, n) {
            return ModClkPt(T, n).at(self.coords.x, self.coords.y.neg());
        }

        // Eq
        pub fn eq(self: ModClkPt(T, n), other: ModClkPt(T, n)) bool {
            return self.coords.x.eq(other.coords.x)
               and self.coords.y.eq(other.coords.y);
        }

        pub fn ne(self: ModClkPt(T, n), other: ModClkPt(T, n)) bool {
            return self.coords.x.ne(other.coords.x)
               and self.coords.y.ne(other.coords.y);
        }

        // Group Operations
        pub fn plus(self: ModClkPt(T, n), other: ModClkPt(T, n)) ModClkPt(T, n) {
            return at(
                (self.coords.x.times(other.coords.y)).plus(self.coords.y.times(other.coords.x)),
                (self.coords.y.times(other.coords.y)).minus(self.coords.x.times(other.coords.x))
            );
        }

        // point-scalar multiplication
        pub fn times(self: ModClkPt(T, n), scalar: T) ModClkPt(T, n) {
            return switch (scalar) {
                0 => ModClkPt(T, n).zero,
                1 => self,
                else => |i| recur: {
                    var q = self.times(@divFloor(i, 2));
                    q = q.plus(q);
                    if (@mod(i, 2) == 1) {
                        q = q.plus(self);
                    }
                    break :recur q;
                }
            };
        }

        // Show
        pub fn format(
            self: ModClkPt(T, n),
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype
        ) !void {
            _ = fmt;
            _ = options;

            try writer.print("({}, {})", .{self.coords.x, self.coords.y});
        }
    };
}

pub fn ClkMod(comptime T: type, comptime n: T) type {
    const FT = ff.IntMod(T, n);
    const MPT = ModClkPt(T, n);
    return struct {
        order: T,

        const zero = MPT.zero;

        pub fn roll_privkey() T {
            return FT.roll().val;
        }

        pub fn from_x(x: T, positive: bool) !MPT {
            return MPT.from_x(FT.init(x), positive);
        }

        pub fn at(l: T, r: T) MPT {
            return MPT.at(FT.init(l), FT.init(r));
        }

        pub fn smallest_nonzero_pt() MPT {
            var i: T = 1;
            while (true) : (i += 1) {
                if (ClkMod(T, n).from_x(i, true)) |cand| {
                    if (cand.coords.y.val > @divFloor(n, 2)) {
                        return cand.reflected();
                    } else {
                        return cand;
                    }
                } else |_| {
                    continue;
                }
            }

            unreachable;
        }
    };
}

const FC7 = ClkMod(i128, 7);

test "finite clock addition" {
    const p1 = FC7.at(2, 5);
    const p2 = FC7.at(1, 0);
    const fore = p1.plus(p2);
    try expect(fore.eq(FC7.at(5, 5)));
    try expect(fore.is_valid());
    const back = p2.plus(p1);
    try expect(fore.eq(back)); // pt_add is commutative

    const p3 = FC7.at(5, 2);
    const l_fst = p1.plus(p2.plus(p3));
    const r_fst = (p1.plus(p2)).plus(p3);
    try expect(l_fst.eq(r_fst)); // pt_add is associative
}

const FC1mil3 = ClkMod(i256, 1000003);

test "large clock addition" {
    const p1 = FC1mil3.at(1000, 2);
    const p2 = p1.plus(p1);
    try expect(p2.eq(FC1mil3.at(4000, 7)));

    const p3 = p2.plus(p1);
    const p4 = p3.plus(p1);
    const p5 = p4.plus(p1);
    const p6 = p5.plus(p1);
    try expect(p6.eq(p3.plus(p3)));
}

test "point-scalar multiplication" {
    const p1 = FC1mil3.at(1000, 2);
    const p3 = p1.plus(p1.plus(p1));
    const p6 = p1.times(6);
    try expect(p6.eq(p3.times(2)));

    const id = p1.times(0);
    try expect(id.eq(p1.times(1000004)));

    const res = FC1mil3.at(541230, 236193);
    try expect(res.eq(p1.times(123456789123456789123456789)));
}

test "finite clock diffie-hellman" {
    const gen = FC1mil3.at(1000, 2);
    try expect(gen.is_valid());
    const alice_priv = FC1mil3.roll_privkey();
    const alice_pub = gen.times(alice_priv);

    const bob_priv = FC1mil3.roll_privkey();
    const bob_pub = gen.times(bob_priv);

    const alice_bob_shared = bob_pub.times(alice_priv);
    const bob_alice_shared = alice_pub.times(bob_priv);
    try expect(alice_bob_shared.eq(bob_alice_shared));
}

test "finite clock point generation" {
    const b = FC1mil3.smallest_nonzero_pt();
    try expect(b.is_valid());
    for (1..100) |_| {
        const s = FC1mil3.roll_privkey();
        const pt = b.times(s);
        try expect(pt.is_valid());
    }
}
