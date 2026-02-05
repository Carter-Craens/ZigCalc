const std = @import("std");

const Kind = enum {
    Length,
    Mass,
    Time,
    Temp,
    Area,
    Volume,
    Speed,
    Force,
    Pressure,
    Current,
    Energy,
    Power,
    Charge,
    Voltage,
    Resistance,
    Capacitance,
    Inductance,
    MagneticFlux,
    Frequency,
    DataSize,
    Angle,
    Data,
};

const UnitDef = struct {
    kind: Kind,
    factor: f128, // multiply to get canonical SI for this kind
    is_affine: bool = false,
    offset: f128 = 0.0,
    si: bool = false,
};

const UnitID = struct { name: []const u8, def: UnitDef };

const SIPrefix = struct { name: []const u8, mul: f128 };

pub const ParsedUnit = struct {
    prefix: ?SIPrefix = null, // null means no prefix
    unit: UnitID,
};

const UNITS = std.StaticStringMap().initComptime(.{
    // Length
    .{ "m", .{ .kind = .Length, .factor = 1.0, .si = true } },
    .{ "in", .{ .kind = .Length, .factor = 0.0254 } },
    .{ "ft", .{ .kind = .Length, .factor = 0.3048 } },
    .{ "yd", .{ .kind = .Length, .factor = 0.9144 } },
    .{ "mi", .{ .kind = .Length, .factor = 1609.344 } },
    .{ "NM", .{ .kind = .Length, .factor = 1852 } },
    .{ "Å", .{ .kind = .Length, .factor = 1.0e-10 } },
    // Length^2)
    .{ "acr", .{ .kind = .Area, .factor = 4046.8564 } },
    .{ "ha", .{ .kind = .Area, .factor = 10000.0 } },
    // + Length^3)
    .{ "L", .{ .kind = .Volume, .factor = 0.001 } },
    .{ "gal", .{ .kind = .Volume, .factor = 0.003785411784 } },
    .{ "qt", .{ .kind = .Volume, .factor = 0.000946352946 } },
    .{ "pt", .{ .kind = .Volume, .factor = 0.000473176473 } },
    .{ "cup", .{ .kind = .Volume, .factor = 0.0002365882365 } },
    //
    .{ "s", .{ .kind = .Time, .factor = 1.0, .si = true } },
    .{ "min", .{ .kind = .Time, .factor = 60.0 } },
    .{ "h", .{ .kind = .Time, .factor = 3600.0 } },
    .{ "day", .{ .kind = .Time, .factor = 86400.0 } },
    //
    .{ "mph", .{ .kind = .Speed, .factor = 0.44704 } },
    .{ "kn", .{ .kind = .Speed, .factor = 0.514444 } },
    //
    .{ "g", .{ .kind = .Mass, .factor = 0.001 } },
    .{ "lb", .{ .kind = .Mass, .factor = 0.45359237 } },
    .{ "oz", .{ .kind = .Mass, .factor = 0.028349523125 } },
    .{ "ton", .{ .kind = .Mass, .factor = 907.18474 } },
    .{ "t", .{ .kind = .Mass, .factor = 1000.0 } },
    // ure
    .{ "K", .{ .kind = .Temp, .factor = 1.0, .si = true } },
    .{ "°C", .{ .kind = .Temp, .factor = 1.0, .affine = true, .offset = 273.15 } },
    .{ "°F:", .{ .kind = .Temp, .factor = 5 / 9, .affine = true, .offset = 255.3722222222 } },
    //
    .{ "N", .{ .kind = .Force, .factor = 1.0, .si = true } },
    .{ "lbf", .{ .kind = .Force, .factor = 4.4482216152605 } },
    //
    .{ "Pa", .{ .kind = .Pressure, .factor = 1.0, .si = true } },
    .{ "bar", .{ .kind = .Pressure, .factor = 100000.0 } },
    .{ "atm", .{ .kind = .Pressure, .factor = 101325.0 } },
    .{ "psi", .{ .kind = .Pressure, .factor = 6894.757293168 } },
    .{ "mmHg", .{ .kind = .Pressure, .factor = 133.3223684211 } },
    .{ "torr", .{ .kind = .Pressure, .factor = 133.3223684211 } },
    //
    .{ "A", .{ .kind = .Current, .factor = 1.0, .si = true } },
    //
    .{ "J", .{ .kind = .Energy, .factor = 1.0, .si = true } },
    .{ "Wh", .{ .kind = .Energy, .factor = 3600.0 } },
    .{ "cal", .{ .kind = .Energy, .factor = 4.184 } },
    .{ "BTU", .{ .kind = .Energy, .factor = 1055.05585262 } },
    .{ "eV", .{ .kind = .Energy, .factor = 1.602176634e-19 } },
    //
    .{ "W", .{ .kind = .Power, .factor = 1.0, .si = true } },
    .{ "hp", .{ .kind = .Power, .factor = 745.6998715822702 } },
    //
    .{ "C", .{ .kind = .Charge, .factor = 1.0, .si = true } },
    .{ "Ah", .{ .kind = .Charge, .factor = 3600.0 } },
    //
    .{ "V", .{ .kind = .Voltage, .factor = 1.0, .si = true } },
    // ce
    .{ "ohm", .{ .kind = .Resistance, .factor = 1.0, .si = true } },
    .{ "Ω", .{ .kind = .Resistance, .factor = 1.0 } },
    // nce
    .{ "F", .{ .kind = .Capacitance, .factor = 1.0, .si = true } },
    // ce
    .{ "H", .{ .kind = .Inductance, .factor = 1.0, .si = true } },
    //  Flux/Density
    .{ "Wb", .{ .kind = .MagneticFlux, .factor = 1.0 } },
    .{ "T", .{ .kind = .MagneticFlux, .factor = 1.0, .si = true } },
    .{ "G", .{ .kind = .MagneticFlux, .factor = 1.0e-4 } },
    // y
    .{ "Hz", .{ .kind = .Frequency, .factor = 1.0, .si = true } },
    .{ "rpm", .{ .kind = .Frequency, .factor = 1 / 60 } },
    //
    .{ "rad", .{ .kind = .Angle, .factor = 1.0, .si = true } },
    .{ "deg", .{ .kind = .Angle, .factor = 3.141592653589793 / 180 } },
    .{ "grad", .{ .kind = .Angle, .factor = 3.141592653589793 / 200 } },
    // e
    .{ "B", .{ .kind = .DataSize, .factor = 8.0 } },
    .{ "b", .{ .kind = .DataSize, .factor = 1.0, .si = true } },
});

const SI_PREFIXES = [_]SIPrefix{
    .{ .name = "Y", .mul = 1e24 },  .{ .name = "Z", .mul = 1e21 },  .{ .name = "E", .mul = 1e18 },
    .{ .name = "P", .mul = 1e15 },  .{ .name = "T", .mul = 1e12 },  .{ .name = "G", .mul = 1e9 },
    .{ .name = "M", .mul = 1e6 },   .{ .name = "k", .mul = 1e3 },   .{ .name = "h", .mul = 1e2 },
    .{ .name = "da", .mul = 1e1 },  .{ .name = "d", .mul = 1e-1 },  .{ .name = "c", .mul = 1e-2 },
    .{ .name = "m", .mul = 1e-3 },  .{ .name = "u", .mul = 1e-6 },  .{ .name = "µ", .mul = 1e-6 },
    .{ .name = "n", .mul = 1e-9 },  .{ .name = "p", .mul = 1e-12 }, .{ .name = "f", .mul = 1e-15 },
    .{ .name = "a", .mul = 1e-18 }, .{ .name = "z", .mul = 1e-21 }, .{ .name = "y", .mul = 1e-24 },
};

const DATA_PREFIXES = [_]SIPrefix{
    .{ .name = "Yi", .mul = 1e24 }, .{ .name = "Zi", .mul = 1e21 }, .{ .name = "Ei", .mul = 1e18 },
    .{ .name = "Pi", .mul = 1e15 }, .{ .name = "Ti", .mul = 1e12 }, .{ .name = "Gi", .mul = 1e9 },
    .{ .name = "Mi", .mul = 1e6 },  .{ .name = "Ki", .mul = 1e3 },  .{ .name = "Hi", .mul = 1e2 },
    .{ .name = "DAi", .mul = 1e1 },
};

pub const ConvertError = error{
    UnknownUnit,
    DimensionMismatch,
    InvalidAffine,
};

// Agnostic functions
pub fn parseToUnit(name: []const u8) !ParsedUnit {
    var matched_prefix: ?SIPrefix = null;
    var unit_start: u8 = 0;

    var maybe_def = UNITS.get(name);

    if (maybe_def != null) {
        return ParsedUnit{
            .SIPrefix = null,
            .unit = UnitID{ .name = name, .def = maybe_def },
        };
    }

    for (SI_PREFIXES) |p| {
        if (p.name.len < name.len) {
            if (std.mem.eql(u8, p.name, name[0..p.name.len]) and (matched_prefix == null or p.name.len > matched_prefix.?.name.len)) {
                matched_prefix = p;
                unit_start = p.name.len;
            }
        }
    }

    const unit_slice: []const u8 = name[unit_start..];
    var best_unit: ?UnitID = null;

    maybe_def = UNITS.get(unit_slice);
    if (maybe_def == null) return ConvertError.UnknownUnit;

    best_unit = UnitID{ .name = unit_slice, .def = maybe_def };

    return ParsedUnit{ .prefix = matched_prefix, .unit = best_unit };
}

pub fn convert(value: f128, from_name: []const u8, to_name: []const u8) !f128 {
    const from_unit: ParsedUnit = parseToUnit(from_name) catch |err| {
        return err;
    };
    const to_unit: ParsedUnit = parseToUnit(to_name) catch |err| {
        return err;
    };

    if (from_unit.unit.kind != to_unit.unit.kind) return ConvertError.DimensionMismatch;

    if ((from_unit.unit.is_affine) and (from_unit.prefix != null or to_unit.prefix != null)) return ConvertError.InvalidAffine;

    const from_scale = from_unit.unit.factor * (if (from_unit.prefix) |p| p.mul else 1.0);
    const to_scale = to_unit.unit.factor * (if (to_unit.prefix) |p| p.mul else 1.0);

    var out_value: f128 = (value + from_unit.unit.offset) * from_scale;
    out_value = (out_value / to_scale) - to_unit.unit.offset;

    return out_value;
}

pub fn toSI(value: f128, from_name: []const u8) !f128 {
    const from_unit: ParsedUnit = parseToUnit(from_name) catch |err| {
        return err;
    };
    const from_scale = from_unit.unit.factor * (if (from_unit.prefix) |p| p.mul else 1.0);
    return (value + from_unit.unit.offset) * from_scale;
}

// Calculator Functions
pub fn convertParsed(value: f128, from_unit: ParsedUnit, to_unit: ParsedUnit) !f128 {
    if (from_unit.unit.kind != to_unit.unit.kind) return ConvertError.DimensionMismatch;

    if ((from_unit.unit.is_affine) and (from_unit.prefix != null or to_unit.prefix != null)) return ConvertError.InvalidAffine;

    const from_scale = from_unit.unit.factor * (if (from_unit.prefix) |p| p.mul else 1.0);
    const to_scale = to_unit.unit.factor * (if (to_unit.prefix) |p| p.mul else 1.0);

    var out_value: f128 = (value + from_unit.unit.offset) * from_scale;
    out_value = (out_value / to_scale) - to_unit.unit.offset;

    return out_value;
}

pub fn toSIParsed(value: f128, from_unit: ParsedUnit) !f128 {}

pub fn getSI(unit: ParsedUnit) ParsedUnit {}
