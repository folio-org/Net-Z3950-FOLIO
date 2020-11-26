use strict;
use warnings;
use utf8;
binmode(STDOUT, "encoding(UTF-8)");

BEGIN {
    use vars qw(@stripDiacriticsTests @regsubTests);
    @stripDiacriticsTests = (
	# value, expected, caption
	[ 'water', 'water', 'null transformation' ],
	[ 'expérience', 'experience', 'e-acute' ],
	[ 'pour célébrer', 'pour celebrer', 'multiple e-acute' ],
	[ 'Museum für Naturkunde', 'Museum fur Naturkunde', 'u-umlaut' ],
	[ 'façade', 'facade', 'cedilla' ],
	[ 'àÀâÂäçéÉèÈêÊëîïôùÙûüÜ', 'aAaAaceEeEeEeiiouUuuU', 'kitchen sink' ],
    );
    @regsubTests = (
	# value, pattern, replacement, flags, expected, caption
	[ 'foobar', 'O', 'x', '', 'foobar', 'case-sensitive non-match' ],
	[ 'foobar', 'O', 'x', 'i', 'fxobar', 'case-insensitive match' ],
	[ 'foobar', 'o', 'x', '', 'fxobar', 'single replacement' ],
	[ 'foobar', 'o', 'x', 'g', 'fxxbar', 'global replacement' ],
	[ 'foobar', '[aeiou]', 'x', 'g', 'fxxbxr', 'replace character class' ],
	[ 'foobar', '[aeiou]', 'X/Y', 'g', 'fX/YX/YbX/Yr', 'replacement containing /' ],
	[ 'foobar', '([aeiou])', '[$1]', 'g', 'f[o][o]b[a]r', 'group reference in pattern' ],
	[ 'foobar', '(.)(.)', '$2$1', 'g', 'ofbora', 'group references in pattern' ],
	[ 'foo/bar', '(.)/(.)', '$2/$1', 'g', 'fob/oar', 'pattern containing /' ],
	[ 'foobar', '(.)\1', 'XXX', 'g', 'fXXXbar', 'back-reference in pattern' ],
    );
}

use Test::More tests => 1 + scalar(@stripDiacriticsTests) + scalar(@regsubTests);

BEGIN { use_ok('Net::Z3950::FOLIO::PostProcess') };
use Net::Z3950::FOLIO::PostProcess qw(applyStripDiacritics applyRegsub applyRule transform postProcess);

foreach my $stripDiacriticsTest (@stripDiacriticsTests) {
    my($value, $expected, $caption) = @$stripDiacriticsTest;
    # use Encode::Guess; my $enc = guess_encoding($value); warn "encoding for '$value' = ", $enc->name();
    my $got = applyStripDiacritics({}, $value);
    is($got, $expected, "stripDiacritics '$value' ($caption)");
}

foreach my $regsubTest (@regsubTests) {
    my($value, $pattern, $replacement, $flags, $expected, $caption) = @$regsubTest;
    my $rule = {
	pattern => $pattern,
	replacement => $replacement,
	flags => $flags,
    };
    my $got = applyRegsub($rule, $value);
    is($got, $expected, "s/$pattern/$replacement/$flags ($caption)");
}
