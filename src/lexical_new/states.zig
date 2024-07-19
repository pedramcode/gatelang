pub const State = enum {
    default,
    err,
    eof,
    whitespace,
    newline,

    integer,
    float,
    ipv4_in,
    ipv4,

    id, // id or keyword
    ipv6_1,
    ipv6_2,
    ipv6_3,
    ipv6_4,
    ipv6_5,
    ipv6_6,
    ipv6,

    string,
    escaped,

    op_not, // !
    op_neql, // !=
    op_plus, // +
    op_pluseql, // +=
    op_plusplus, // ++
    op_minus, // -
    op_minuseql, // -=
    op_minusminus, // --
    op_mult, // *
    op_multeql, // *=
    op_div, // /
    op_diveql, // /=
    op_assign, // =
    op_eql, // ==
    op_less, // <
    op_lesseql, // <=
    op_shiftleft, // <<
    op_great, // >
    op_greateql, // >=
    op_shiftright, // >>

    comment,

    pun_prntopen, // (
    pun_prntclose, // )
    pun_curopen, // {
    pun_curclose, // }
    pun_brkopen, // [
    pun_brkclose, // ]
    pun_semi, // ;
    pun_comma, // ,
};
